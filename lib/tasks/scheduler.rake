# frozen_string_literal: true

namespace :vaccinesignup do
  desc 'Back-up production data and restore to the local environment.'
  task back_up: :environment do
    sh 'heroku pg:backups:download'
    sh 'pg_restore --verbose --clean --no-acl --no-owner -h localhost -d vaccine_notifier latest.dump'
  end

  desc 'Read DMs and, if there are subscribed zip codes, notify users.'
  task read_and_notify: :environment do
    results = NotifyBot.call
    log_notification_results(results) if results && Rails.env.development?
  end

  desc 'Sync Locations and, if there are changes, notify users.'
  task sync_and_notify: :environment do
    results = SyncAndNotifyBot.call
    next unless Rails.env.development?

    if results[:total]
      puts "Parsed #{results[:total]}, created #{results[:new]}, updated #{results[:updated]} Locations, which "\
           "affected these zips: #{results[:zips]}."
    else
      log_notification_results(results)
    end
  end

  private

  def log_notification_results(results)
    puts "Notified #{results[:users]} users about #{results[:clinics]} appointments."
  end
end
