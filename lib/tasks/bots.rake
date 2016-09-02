namespace :botmetrics do
  desc "setup facebook dashboards"
  task :setup_facebook_dashboards => :environment do
    Bot.where(provider: 'facebook').find_each do |bot|
      owner = bot.owners.first
      if owner.blank?
        raise ArgumentError, "omg owner blank for bot: #{bot.inspect}"
      end

      bot.create_default_dashboards_with!(owner)
    end
  end

  desc "backfill_mixpanel_first_received_event_at"
  task :backfill_mixpanel_first_received_event_at => :environment do
    Bot.where(first_received_event_at: nil).find_each do |bot|
      if bot.first_received_event_at.blank?
        first_event = bot.events.order("id").first
        if first_event.present?
          bot.update_attribute(:first_received_event_at, first_event.created_at)
          bot.collaborators.each do |user|
            SetMixpanelPropertyJob.perform_async(user.id, "received_first_event", true)
            puts "Updated #{user.id} #{user.email} received_first_event=true on Mixpanel"
          end
        end
      end
    end
  end
end

