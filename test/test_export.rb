require "bundler/setup"
require "minitest/autorun"
require "json"
require "sqlite3"
require "fileutils"
require "tmpdir"

class TestExport < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, "questions.sqlite")
    @output_dir = File.join(@tmpdir, "docs")
    @output_path = File.join(@output_dir, "questions.json")
    create_and_populate_db
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def create_and_populate_db
    db = SQLite3::Database.new(@db_path)
    db.execute <<~SQL
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        difficulty TEXT NOT NULL, question TEXT NOT NULL,
        answer TEXT NOT NULL, explanation TEXT NOT NULL,
        rule_refs TEXT, cards_ref TEXT, tags TEXT,
        status TEXT DEFAULT 'pending',
        created_at TEXT DEFAULT (datetime('now')),
        reviewed_at TEXT
      );
    SQL

    # Insert questions with different statuses
    [
      ["fundamentals", "Q1?", "A1", "E1", '["500.1"]', '[]', '["turns"]', "approved"],
      ["stack_triggers", "Q2?", "A2", "E2", '["603.2"]', '["Blood Moon"]', '["stack"]', "approved"],
      ["fundamentals", "Q3?", "A3", "E3", nil, nil, nil, "pending"],
      ["fundamentals", "Q4?", "A4", "E4", '["117.1"]', '[]', '[]', "rejected"]
    ].each do |row|
      db.execute("INSERT INTO questions (difficulty, question, answer, explanation, rule_refs, cards_ref, tags, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", row)
    end

    db.close
  end

  def run_export
    FileUtils.mkdir_p(@output_dir)
    db = SQLite3::Database.new(@db_path)
    db.results_as_hash = true
    rows = db.execute("SELECT * FROM questions WHERE status = 'approved' ORDER BY id")
    db.close

    exported = rows.map do |row|
      {
        "id" => row["id"],
        "difficulty" => row["difficulty"],
        "question" => row["question"],
        "answer" => row["answer"],
        "explanation" => row["explanation"],
        "rule_refs" => row["rule_refs"] ? JSON.parse(row["rule_refs"]) : [],
        "cards_ref" => row["cards_ref"] ? JSON.parse(row["cards_ref"]) : [],
        "tags" => row["tags"] ? JSON.parse(row["tags"]) : []
      }
    end

    File.write(@output_path, JSON.pretty_generate(exported))
    exported
  end

  def test_exports_only_approved
    exported = run_export
    assert_equal 2, exported.length
  end

  def test_exported_ids_match_database
    exported = run_export
    assert_equal 1, exported[0]["id"]
    assert_equal 2, exported[1]["id"]
  end

  def test_strips_internal_fields
    exported = run_export
    exported.each do |q|
      refute q.key?("status"), "Exported question should not have 'status'"
      refute q.key?("created_at"), "Exported question should not have 'created_at'"
      refute q.key?("reviewed_at"), "Exported question should not have 'reviewed_at'"
    end
  end

  def test_correct_json_shape
    exported = run_export
    q = exported.first

    assert_equal "fundamentals", q["difficulty"]
    assert_equal "Q1?", q["question"]
    assert_equal "A1", q["answer"]
    assert_equal "E1", q["explanation"]
    assert_equal ["500.1"], q["rule_refs"]
    assert_equal [], q["cards_ref"]
    assert_equal ["turns"], q["tags"]
  end

  def test_json_arrays_are_parsed
    exported = run_export
    q = exported[1]

    assert_kind_of Array, q["rule_refs"]
    assert_kind_of Array, q["cards_ref"]
    assert_kind_of Array, q["tags"]
    assert_equal ["Blood Moon"], q["cards_ref"]
  end

  def test_nil_arrays_become_empty_arrays
    # Approve the pending question with nil arrays
    db = SQLite3::Database.new(@db_path)
    db.execute("UPDATE questions SET status = 'approved' WHERE id = 3")
    db.close

    exported = run_export
    q3 = exported.find { |q| q["id"] == 3 }

    assert_equal [], q3["rule_refs"]
    assert_equal [], q3["cards_ref"]
    assert_equal [], q3["tags"]
  end

  def test_output_is_valid_json_file
    run_export

    content = File.read(@output_path)
    parsed = JSON.parse(content)

    assert_kind_of Array, parsed
    assert_equal 2, parsed.length
  end
end
