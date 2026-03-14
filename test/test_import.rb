require "bundler/setup"
require "minitest/autorun"
require "json"
require "sqlite3"
require "fileutils"
require "tmpdir"

class TestImport < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, "questions.sqlite")
    create_questions_table(@db_path)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def create_questions_table(db_path)
    db = SQLite3::Database.new(db_path)
    db.execute <<~SQL
      CREATE TABLE IF NOT EXISTS questions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        difficulty  TEXT NOT NULL,
        question    TEXT NOT NULL,
        answer      TEXT NOT NULL,
        explanation TEXT NOT NULL,
        rule_refs   TEXT,
        cards_ref   TEXT,
        tags        TEXT,
        status      TEXT DEFAULT 'pending',
        created_at  TEXT DEFAULT (datetime('now')),
        reviewed_at TEXT
      );
    SQL
    db.close
  end

  def valid_question(overrides = {})
    {
      "difficulty" => "fundamentals",
      "question" => "What happens during the untap step?",
      "answer" => "The active player untaps all their tapped permanents.",
      "explanation" => "During the untap step, all phased-in permanents the active player controls untap.",
      "rule_refs" => ["502.3"],
      "cards_ref" => [],
      "tags" => ["turn_structure"]
    }.merge(overrides)
  end

  def import_questions(questions, db_path)
    json_file = File.join(@tmpdir, "batch.json")
    File.write(json_file, JSON.generate(questions))

    difficulty_levels = %w[fundamentals multiplayer 2hg stack_triggers interactions edge_cases]
    required_fields = %w[difficulty question answer explanation]

    parsed = JSON.parse(File.read(json_file))
    raise "Expected array" unless parsed.is_a?(Array)

    parsed.each_with_index do |q, i|
      required_fields.each do |field|
        if q[field].nil? || q[field].to_s.strip.empty?
          raise "Question #{i + 1}: missing '#{field}'"
        end
      end
      unless difficulty_levels.include?(q["difficulty"])
        raise "Question #{i + 1}: unknown difficulty '#{q["difficulty"]}'"
      end
    end

    db = SQLite3::Database.new(db_path)
    ids = []

    parsed.each do |q|
      db.execute(
        "INSERT INTO questions (difficulty, question, answer, explanation, rule_refs, cards_ref, tags) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [
          q["difficulty"],
          q["question"],
          q["answer"],
          q["explanation"],
          q["rule_refs"]&.then { |r| r.is_a?(Array) ? JSON.generate(r) : r },
          q["cards_ref"]&.then { |r| r.is_a?(Array) ? JSON.generate(r) : r },
          q["tags"]&.then { |r| r.is_a?(Array) ? JSON.generate(r) : r }
        ]
      )
      ids << db.last_insert_row_id
    end

    db.close
    ids
  end

  def test_imports_valid_json
    questions = [valid_question, valid_question("question" => "Another question?")]
    ids = import_questions(questions, @db_path)

    assert_equal 2, ids.length

    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    rows = db.execute("SELECT * FROM questions")
    db.close

    assert_equal 2, rows.length
    assert_equal "fundamentals", rows[0]["difficulty"]
    assert_equal "pending", rows[0]["status"]
  end

  def test_generates_autoincrement_ids
    questions = [valid_question, valid_question, valid_question]
    ids = import_questions(questions, @db_path)

    assert_equal [1, 2, 3], ids
  end

  def test_stores_json_arrays_correctly
    q = valid_question(
      "rule_refs" => ["603.2", "603.3b"],
      "cards_ref" => ["Blood Moon"],
      "tags" => ["layers", "replacement"]
    )
    import_questions([q], @db_path)

    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    row = db.execute("SELECT * FROM questions").first
    db.close

    assert_equal '["603.2","603.3b"]', row["rule_refs"]
    assert_equal '["Blood Moon"]', row["cards_ref"]
    assert_equal '["layers","replacement"]', row["tags"]
  end

  def test_rejects_missing_required_field
    %w[difficulty question answer explanation].each do |field|
      q = valid_question(field => nil)
      err = assert_raises(RuntimeError) { import_questions([q], @db_path) }
      assert_includes err.message, field
    end
  end

  def test_rejects_empty_required_field
    q = valid_question("question" => "   ")
    err = assert_raises(RuntimeError) { import_questions([q], @db_path) }
    assert_includes err.message, "question"
  end

  def test_rejects_unknown_difficulty
    q = valid_question("difficulty" => "super_hard")
    err = assert_raises(RuntimeError) { import_questions([q], @db_path) }
    assert_includes err.message, "unknown difficulty"
  end

  def test_accepts_all_valid_difficulty_levels
    levels = %w[fundamentals multiplayer 2hg stack_triggers interactions edge_cases]
    questions = levels.map { |l| valid_question("difficulty" => l) }
    ids = import_questions(questions, @db_path)

    assert_equal 6, ids.length
  end

  def test_handles_nil_optional_fields
    q = valid_question.tap { |h| h.delete("rule_refs"); h.delete("cards_ref"); h.delete("tags") }
    ids = import_questions([q], @db_path)

    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    row = db.execute("SELECT * FROM questions").first
    db.close

    assert_equal 1, ids.length
    assert_nil row["rule_refs"]
    assert_nil row["cards_ref"]
    assert_nil row["tags"]
  end
end
