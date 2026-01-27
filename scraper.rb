#!/usr/bin/env ruby
# frozen_string_literal: true

require "scraperwiki"
require "mechanize"

class Scraper
  INITIAL_PAGE_URL = "https://www.clarence.nsw.gov.au/Building-and-planning/Development-applications/Advertised-DAs"
  STATE = "NSW"

  def clean_whitespace(text)
    text.gsub("\r", " ").gsub("\n", " ").squeeze(" ").strip
  end

  attr_accessor :pause_duration

  def throttle_block(extra_delay: 0.5)
    if @pause_duration
      puts "  Pausing #{@pause_duration}s"
      sleep(@pause_duration)
    end
    start_time = Time.now.to_f
    page = yield
    @pause_duration = (Time.now.to_f - start_time + extra_delay).round(3)
    page
  end

  def cleanup_old_records
    cutoff_date = (Date.today - 30).to_s
    vacuum_cutoff_date = (Date.today - 35).to_s

    stats = ScraperWiki.sqliteexecute(
      "SELECT COUNT(*) as count, MIN(date_scraped) as oldest FROM data WHERE date_scraped < ?",
      [cutoff_date]
    ).first

    deleted_count = stats["count"]
    oldest_date = stats["oldest"]

    return unless deleted_count.positive? || ENV["VACUUM"]

    puts "Deleting #{deleted_count} applications scraped between #{oldest_date} and #{cutoff_date}"
    ScraperWiki.sqliteexecute("DELETE FROM data WHERE date_scraped < ?", [cutoff_date])

    return unless rand < 0.03 || (oldest_date && oldest_date < vacuum_cutoff_date) || ENV["VACUUM"]

    puts "  Running VACUUM to reclaim space..."
    ScraperWiki.sqliteexecute("VACUUM")
  end

  def run
    agent = Mechanize.new
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

    page = throttle_block do
      puts "Getting advertised DAs page"
      agent.get(INITIAL_PAGE_URL)
    end

    # Find all DA articles
    container = page.at("div.da-list-container")
    raise "Could not find DA list container" unless container

    articles = container.search("article")
    added = found = 0

    articles.each do |article|
      found += 1

      link = article.at("a")
      next unless link

      info_url = link["href"]
      council_reference = article.at("p.da-application-number")&.text&.strip
      address = article.at("p.list-item-address")&.text&.strip
      address = "#{address}, #{STATE}" if address.to_s != "" && !address.end_with?(STATE)

      # Description is the first <p> without a class
      description = link.search("p").find { |p| !p["class"] }&.text&.strip

      unless council_reference
        puts "Warning: No council reference found! (skipped)"
        next
      end
      unless address
        puts "Warning: No address found! (skipped)"
        next
      end
      unless description
        puts "Warning: No description found! (skipped)"
        next
      end

      record = {
        "council_reference" => council_reference,
        "address" => address,
        "description" => clean_whitespace(description),
        "info_url" => info_url,
        "date_scraped" => Date.today.to_s,
      }

      added += 1
      puts "Saving record #{council_reference} - #{address}"
      ScraperWiki.save_sqlite(["council_reference"], record)
    end

    cleanup_old_records
    puts "Added #{added} records, and skipped #{found - added} unprocessable records."

    # Check pagination
    pagination = page.at("div.seamless-pagination-info")
    if pagination
      pagination_text = clean_whitespace(pagination.text)
      puts "Found pagination: #{pagination_text}"

      unless pagination_text == "Page 1 of 1"
        warn "ERROR: Multiple pages detected but pagination not implemented!"
        exit 1
      end
    else
      warn "ERROR: Unable to detect if further pages exist!"
      exit 2
    end
    puts "Finished!"
  end
end

Scraper.new.run if __FILE__ == $PROGRAM_NAME
