require "bundler/setup"
require "net/http"
require "json"
require "uri"
require "fileutils"
require "digest"
require "sqlite3"

DATA_DIR = File.expand_path("data", __dir__)
MTGJSON_SQLITE = File.join(DATA_DIR, "AllPrintings.sqlite")
QUESTIONS_SQLITE = File.join(DATA_DIR, "questions.sqlite")
CR_FILE = File.join(DATA_DIR, "comprehensive_rules.txt")
DOCS_DIR = File.expand_path("docs", __dir__)

MTGJSON_META_URL = "https://mtgjson.com/api/v5/Meta.json"
MTGJSON_SQLITE_URL = "https://mtgjson.com/api/v5/AllPrintings.sqlite"
MTGJSON_SHA256_URL = "https://mtgjson.com/api/v5/AllPrintings.sqlite.sha256"

DIFFICULTY_LEVELS = %w[fundamentals multiplayer 2hg stack_triggers interactions edge_cases].freeze

namespace :data do
  desc "Download MTGJSON (auto version check) + Comprehensive Rules (prompts for URL)"
  task :update do
    FileUtils.mkdir_p(DATA_DIR)

    update_mtgjson
    update_comprehensive_rules
  end
end

namespace :db do
  desc "Create questions table in data/questions.sqlite"
  task :setup do
    FileUtils.mkdir_p(DATA_DIR)

    db = SQLite3::Database.new(QUESTIONS_SQLITE)
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

    count = SQLite3::Database.new(QUESTIONS_SQLITE).get_first_value("SELECT COUNT(*) FROM questions")
    puts "questions table ready (#{count} existing rows)"
  end
end

task :test do
  Dir.glob("test/test_*.rb").each { |f| require_relative f }
end

# --- Helper methods ---

def update_mtgjson
  local_version = local_mtgjson_version
  remote_meta = fetch_remote_meta

  if local_version && local_version == remote_meta["version"]
    puts "MTGJSON is up to date (#{local_version})"
    return
  end

  if local_version
    puts "MTGJSON update available: #{local_version} → #{remote_meta["version"]}"
  else
    puts "No local MTGJSON found. Downloading..."
  end

  puts "Downloading AllPrintings.sqlite (~540MB)..."
  download_file(MTGJSON_SQLITE_URL, MTGJSON_SQLITE)

  puts "Verifying SHA256..."
  verify_sha256(MTGJSON_SQLITE)

  new_version = local_mtgjson_version
  puts "MTGJSON updated to #{new_version}"
end

def local_mtgjson_version
  return nil unless File.exist?(MTGJSON_SQLITE)

  db = SQLite3::Database.new(MTGJSON_SQLITE)
  version = db.get_first_value("SELECT version FROM meta LIMIT 1")
  db.close
  version
rescue SQLite3::Exception
  nil
end

def fetch_remote_meta
  uri = URI(MTGJSON_META_URL)
  response = Net::HTTP.get(uri)
  JSON.parse(response).fetch("data", JSON.parse(response))
rescue StandardError => e
  abort "Failed to fetch MTGJSON metadata: #{e.message}"
end

def update_comprehensive_rules
  print "\nPaste the Comprehensive Rules .txt URL\n(from https://magic.wizards.com/en/rules): "
  url = $stdin.gets&.strip

  if url.nil? || url.empty?
    puts "Skipped CR download."
    return
  end

  puts "Downloading Comprehensive Rules..."
  download_file(url, CR_FILE)
  puts "Saved to #{CR_FILE}"
end

def download_file(url, destination)
  uri = URI(url)
  tmp = "#{destination}.tmp"

  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 600) do |http|
    request = Net::HTTP::Get.new(uri)

    http.request(request) do |response|
      case response
      when Net::HTTPRedirection
        download_file(response["location"], destination)
        return
      when Net::HTTPSuccess
        total = response["content-length"]&.to_i
        downloaded = 0

        File.open(tmp, "wb") do |file|
          response.read_body do |chunk|
            file.write(chunk)
            downloaded += chunk.size
            if total && total > 0
              pct = (downloaded.to_f / total * 100).round(1)
              print "\r  #{downloaded / 1_048_576}MB / #{total / 1_048_576}MB (#{pct}%)"
            else
              print "\r  #{downloaded / 1_048_576}MB downloaded"
            end
          end
        end
        puts
      else
        abort "Download failed: #{response.code} #{response.message}"
      end
    end
  end

  FileUtils.mv(tmp, destination)
end

def verify_sha256(filepath)
  uri = URI(MTGJSON_SHA256_URL)
  expected = Net::HTTP.get(uri).strip.split.first.downcase

  actual = Digest::SHA256.file(filepath).hexdigest

  if actual == expected
    puts "SHA256 verified."
  else
    abort "SHA256 mismatch!\n  Expected: #{expected}\n  Actual:   #{actual}"
  end
rescue StandardError => e
  puts "Warning: could not verify SHA256 (#{e.message}). Continuing anyway."
end
