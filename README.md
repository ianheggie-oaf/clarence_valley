# Clarence Valley Council NSW Advertised DAs Scraper

approx pop 62K

* Cookie tracking - No
* Pagnation - maybe, but we don't have an example to code for
* Javascript - No
* Clearly defined data within a row - Yes
* System - Powered by Granicus

This is a scraper that runs on [Morph](https://morph.io). 
To get started [see the documentation](https://morph.io/documentation)

Add any issues to https://github.com/planningalerts-scrapers/issues/issues

## To run the scraper

    bundle exec ruby scraper.rb

### Expected output

```
Getting advertised DAs page
Saving record DA2025/0572 - 115 River Street, Maclean 2463, NSW
...
Saving record DA2026/0004 - 208 Bacon Street, Grafton 2460, NSW
Deleting 0 applications scraped between  and 2025-12-29
  Running VACUUM to reclaim space...
Added 7 records, and skipped 0 unprocessable records.
Found pagination: Page 1 of 1
Finished!
```

Execution time: ~ 2 seconds

## To run style and coding checks

    bundle exec rubocop

## To check for security updates

    gem install bundler-audit
    bundle-audit
