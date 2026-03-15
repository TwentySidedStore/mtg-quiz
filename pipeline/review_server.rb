require "webrick"
require "json"
require "sqlite3"

QUESTIONS_DB = File.expand_path("../data/questions.sqlite", __dir__)
REVIEW_DIR = File.expand_path("../review", __dir__)

VALID_STATUSES = %w[pending approved rejected].freeze
VALID_DIFFICULTIES = %w[fundamentals multiplayer 2hg stack_triggers interactions edge_cases event_procedures].freeze

def open_db
  db = SQLite3::Database.new(QUESTIONS_DB)
  db.results_as_hash = true
  db
end

def parse_question_row(row)
  {
    "id" => row["id"],
    "difficulty" => row["difficulty"],
    "question" => row["question"],
    "answer" => row["answer"],
    "explanation" => row["explanation"],
    "rule_refs" => row["rule_refs"] ? JSON.parse(row["rule_refs"]) : [],
    "cards_ref" => row["cards_ref"] ? JSON.parse(row["cards_ref"]) : [],
    "tags" => row["tags"] ? JSON.parse(row["tags"]) : [],
    "status" => row["status"],
    "created_at" => row["created_at"],
    "reviewed_at" => row["reviewed_at"]
  }
end

def json_response(response, status, body)
  response.status = status
  response["Content-Type"] = "application/json"
  response.body = JSON.generate(body)
end

server = WEBrick::HTTPServer.new(
  Port: 4567,
  BindAddress: "127.0.0.1",
  Logger: WEBrick::Log.new($stdout, WEBrick::Log::INFO),
  AccessLog: [[File.open(File::NULL, "w"), WEBrick::AccessLog::COMMON_LOG_FORMAT]]
)

# Serve review/index.html
server.mount("/", WEBrick::HTTPServlet::FileHandler, REVIEW_DIR)

# GET /api/questions?status=pending — list questions
# PATCH /api/questions?id=5 — update a question
server.mount_proc("/api/questions") do |req, res|
  case req.request_method
  when "GET"
    db = open_db
    status_filter = req.query["status"]&.to_s&.encode("UTF-8")

    rows = if status_filter && VALID_STATUSES.include?(status_filter)
      db.execute("SELECT * FROM questions WHERE status = ? ORDER BY id", [status_filter.to_s])
    else
      db.execute("SELECT * FROM questions ORDER BY id")
    end
    db.close

    json_response(res, 200, rows.map { |r| parse_question_row(r) })

  when "POST"
    body = begin
      JSON.parse(req.body)
    rescue JSON::ParserError
      json_response(res, 400, { "error" => "Invalid JSON body" })
      next
    end

    id = body.delete("id")&.to_s
    if id.nil? || id.empty?
      json_response(res, 400, { "error" => "Missing id in request body" })
      next
    end

    db = open_db

    existing = db.execute("SELECT * FROM questions WHERE id = ?", [id]).first
    unless existing
      db.close
      json_response(res, 404, { "error" => "Question not found" })
      next
    end

    updatable_fields = %w[difficulty question answer explanation rule_refs cards_ref tags status]
    sets = []
    values = []

    updatable_fields.each do |field|
      next unless body.key?(field)
      value = body[field]

      if field == "status" && !VALID_STATUSES.include?(value)
        db.close
        json_response(res, 400, { "error" => "Invalid status: #{value}" })
        next
      end

      if field == "difficulty" && !VALID_DIFFICULTIES.include?(value)
        db.close
        json_response(res, 400, { "error" => "Invalid difficulty: #{value}" })
        next
      end

      if %w[rule_refs cards_ref tags].include?(field) && value.is_a?(Array)
        value = JSON.generate(value)
      end

      sets << "#{field} = ?"
      values << value
    end

    if sets.empty?
      db.close
      json_response(res, 400, { "error" => "No valid fields to update" })
      next
    end

    sets << "reviewed_at = datetime('now')" if body.key?("status")

    values << id
    db.execute("UPDATE questions SET #{sets.join(", ")} WHERE id = ?", values)

    updated = db.execute("SELECT * FROM questions WHERE id = ?", [id]).first
    db.close

    json_response(res, 200, parse_question_row(updated))
  else
    json_response(res, 405, { "error" => "Method not allowed" })
  end
end

# GET /api/stats
server.mount_proc("/api/stats") do |req, res|
  db = open_db
  stats = {}
  VALID_STATUSES.each do |s|
    stats[s] = db.get_first_value("SELECT COUNT(*) FROM questions WHERE status = ?", [s])
  end
  db.close

  json_response(res, 200, stats)
end

trap("INT") { server.shutdown }
trap("TERM") { server.shutdown }

puts "Review server starting at http://127.0.0.1:4567"
puts "Press Ctrl+C to stop"
server.start
