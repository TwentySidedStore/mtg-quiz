require "bundler/setup"
require "minitest/autorun"
require "json"
require "sqlite3"
require "fileutils"
require "tmpdir"
require "net/http"
require "webrick"

class TestReviewServer < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, "questions.sqlite")
    create_and_populate_db

    @port = 9000 + rand(1000)
    start_server
  end

  def teardown
    @server&.shutdown
    @server_thread&.join(2)
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

    [
      ["fundamentals", "Q1?", "A1", "E1", '["500.1"]', '[]', '["turns"]', "pending"],
      ["stack_triggers", "Q2?", "A2", "E2", '["603.2"]', '[]', '["stack"]', "approved"],
      ["fundamentals", "Q3?", "A3", "E3", nil, nil, nil, "rejected"]
    ].each do |row|
      db.execute("INSERT INTO questions (difficulty, question, answer, explanation, rule_refs, cards_ref, tags, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", row)
    end

    db.close
  end

  def start_server
    db_path = @db_path
    valid_statuses = %w[pending approved rejected]

    @server = WEBrick::HTTPServer.new(
      Port: @port, BindAddress: "127.0.0.1",
      Logger: WEBrick::Log.new(File::NULL), AccessLog: []
    )

    open_db = -> {
      db = SQLite3::Database.new(db_path)
      db.results_as_hash = true
      db
    }

    parse_row = ->(row) {
      {
        "id" => row["id"], "difficulty" => row["difficulty"],
        "question" => row["question"], "answer" => row["answer"],
        "explanation" => row["explanation"],
        "rule_refs" => row["rule_refs"] ? JSON.parse(row["rule_refs"]) : [],
        "cards_ref" => row["cards_ref"] ? JSON.parse(row["cards_ref"]) : [],
        "tags" => row["tags"] ? JSON.parse(row["tags"]) : [],
        "status" => row["status"],
        "created_at" => row["created_at"], "reviewed_at" => row["reviewed_at"]
      }
    }

    @server.mount_proc("/api/questions") do |req, res|
      res["Content-Type"] = "application/json"

      case req.request_method
      when "GET"
        db = open_db.call
        sf = req.query["status"]&.to_s&.encode("UTF-8")
        rows = if sf && !sf.empty? && valid_statuses.include?(sf)
          db.execute("SELECT * FROM questions WHERE status = ? ORDER BY id", [sf])
        else
          db.execute("SELECT * FROM questions ORDER BY id")
        end
        db.close
        res.body = JSON.generate(rows.map { |r| parse_row.call(r) })

      when "POST"
        body = JSON.parse(req.body)
        id = body.delete("id")&.to_s
        db = open_db.call

        sets = []
        values = []
        %w[difficulty question answer explanation rule_refs cards_ref tags status].each do |field|
          next unless body.key?(field)
          value = body[field]
          value = JSON.generate(value) if %w[rule_refs cards_ref tags].include?(field) && value.is_a?(Array)
          sets << "#{field} = ?"
          values << value
        end

        sets << "reviewed_at = datetime('now')" if body.key?("status")

        values << id
        db.execute("UPDATE questions SET #{sets.join(", ")} WHERE id = ?", values)
        updated = db.execute("SELECT * FROM questions WHERE id = ?", [id]).first
        db.close
        res.body = JSON.generate(parse_row.call(updated))
      end
    end

    @server.mount_proc("/api/stats") do |req, res|
      db = open_db.call
      stats = {}
      valid_statuses.each { |s| stats[s] = db.get_first_value("SELECT COUNT(*) FROM questions WHERE status = ?", [s]) }
      db.close
      res["Content-Type"] = "application/json"
      res.body = JSON.generate(stats)
    end

    @server_thread = Thread.new { @server.start }
    sleep 0.5
  end

  def get(path)
    uri = URI("http://127.0.0.1:#{@port}#{path}")
    res = Net::HTTP.get_response(uri)
    [res.code.to_i, JSON.parse(res.body)]
  end

  def post_update(id, body)
    uri = URI("http://127.0.0.1:#{@port}/api/questions")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    req.body = JSON.generate(body.merge("id" => id))
    res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
    [res.code.to_i, JSON.parse(res.body)]
  end

  def test_get_all_questions
    status, body = get("/api/questions")
    assert_equal 200, status
    assert_equal 3, body.length
  end

  def test_filter_by_status
    status, body = get("/api/questions?status=pending")
    assert_equal 200, status
    assert_equal 1, body.length
    assert_equal "pending", body[0]["status"]
  end

  def test_stats
    status, body = get("/api/stats")
    assert_equal 200, status
    assert_equal 1, body["pending"]
    assert_equal 1, body["approved"]
    assert_equal 1, body["rejected"]
  end

  def test_post_updates_status
    status, body = post_update(1, { "status" => "approved" })
    assert_equal 200, status
    assert_equal "approved", body["status"]
    refute_nil body["reviewed_at"]
  end

  def test_post_updates_fields
    status, body = post_update(1, {
      "question" => "Updated question?",
      "answer" => "Updated answer",
      "difficulty" => "edge_cases"
    })
    assert_equal 200, status
    assert_equal "Updated question?", body["question"]
    assert_equal "Updated answer", body["answer"]
    assert_equal "edge_cases", body["difficulty"]
  end

  def test_post_updates_arrays
    status, body = post_update(1, {
      "rule_refs" => ["100.1", "200.2"],
      "tags" => ["new_tag"]
    })
    assert_equal 200, status
    assert_equal ["100.1", "200.2"], body["rule_refs"]
    assert_equal ["new_tag"], body["tags"]
  end
end
