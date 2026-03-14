require "bundler/setup"
require "minitest/autorun"
require "sqlite3"
require "fileutils"
require "tmpdir"

class TestDbSetup < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, "questions.sqlite")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def create_table(db_path)
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
    db
  end

  def test_creates_table_with_correct_columns
    db = create_table(@db_path)

    columns = db.table_info("questions")
    column_names = columns.map { |c| c["name"] }

    expected = %w[id difficulty question answer explanation rule_refs cards_ref tags status created_at reviewed_at]
    assert_equal expected, column_names

    db.close
  end

  def test_id_is_autoincrement_integer
    db = create_table(@db_path)

    id_col = db.table_info("questions").find { |c| c["name"] == "id" }
    assert_equal "integer", id_col["type"].downcase
    assert_equal 1, id_col["pk"]

    db.close
  end

  def test_required_fields_are_not_null
    db = create_table(@db_path)

    not_null_columns = db.table_info("questions")
      .select { |c| c["notnull"] == 1 }
      .map { |c| c["name"] }

    %w[difficulty question answer explanation].each do |col|
      assert_includes not_null_columns, col
    end

    db.close
  end

  def test_status_defaults_to_pending
    db = create_table(@db_path)

    status_col = db.table_info("questions").find { |c| c["name"] == "status" }
    assert_includes status_col["dflt_value"].to_s, "pending"

    db.close
  end

  def test_create_is_idempotent
    create_table(@db_path).close
    db = create_table(@db_path)

    # Insert a row, then create table again — row should survive
    db.execute("INSERT INTO questions (difficulty, question, answer, explanation) VALUES (?, ?, ?, ?)",
      ["fundamentals", "test q", "test a", "test e"])
    db.close

    db = create_table(@db_path)
    count = db.get_first_value("SELECT COUNT(*) FROM questions")
    assert_equal 1, count

    db.close
  end
end
