class DashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :find_bot
  before_action :find_instances
  before_action :init_detail_view!
  layout 'app'

  def new_bots
    @tableized = @instances.with_new_bots(@start.utc, @end.utc).page(params[:page])

    @new_bots = GetBotInstancesCountByUnit.new(@group_by, @instances, start_time: @start, end_time: @end, user_time_zone: current_user.timezone).call

    TrackMixpanelEventJob.perform_async('Viewed New Bots Dashboard Page', current_user.id)
  end

  def disabled_bots
    @events = Event.where(event_type: 'bot_disabled', bot_instance_id: @instances.select(:id), created_at: @start.utc..@end.utc)

    @tableized = @instances.
                    select("bot_instances.*, COALESCE(users.cnt, 0) AS users_count, e.c_at AS last_event_at").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt FROM bot_users GROUP BY bot_instance_id) users on users.bot_instance_id = bot_instances.id").
                    joins("INNER JOIN (SELECT bot_instance_id, MAX(events.created_at) AS c_at FROM events WHERE events.event_type = 'bot_disabled' GROUP by bot_instance_id) e ON e.bot_instance_id = bot_instances.id").
                    where("bot_instances.id IN (?)", @events.select(:bot_instance_id)).
                    order("last_event_at DESC").
                    page(params[:page])

    @events = GetBotInstancesCountByUnit.new(@group_by, @events, user_time_zone: current_user.timezone).call

    TrackMixpanelEventJob.perform_async('Viewed Disabled Bots Dashboard Page', current_user.id)
  end

  def users
    @users = BotUser.where(bot_instance_id: @instances.select(:id)).joins(:bot_instance).
                     where("bot_instances.created_at" => @start.utc..@end.utc)

    @tableized = @users.order("bot_instances.created_at DESC").page(params[:page])

    @users = GetBotInstancesCountByUnit.new(@group_by, @users, start_time: @start, end_time: @end, user_time_zone: current_user.timezone).call

    TrackMixpanelEventJob.perform_async('Viewed New Users Dashboard Page', current_user.id)
  end

  def all_messages
    @messages = Event.where(bot_instance_id: @instances.select(:id),
                            event_type: 'message',
                            is_from_bot: false,
                            created_at: @start.utc..@end.utc)

    @tableized = @instances.
                    select("bot_instances.*, COALESCE(users.cnt, 0) AS users_count, COALESCE(e.cnt, 0) AS events_count, e.c_at AS last_event_at").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt FROM bot_users GROUP BY bot_instance_id) users on users.bot_instance_id = bot_instances.id").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt, MAX(events.created_at) AS c_at FROM events WHERE events.event_type = 'message' AND events.is_from_bot = 'f' GROUP by bot_instance_id) e ON e.bot_instance_id = bot_instances.id").
                    where("bot_instances.id IN (?)", @messages.select(:bot_instance_id)).
                    order("last_event_at DESC").
                    page(params[:page])

    @messages = GetBotInstancesCountByUnit.new(@group_by, @messages, user_time_zone: current_user.timezone).call

    TrackMixpanelEventJob.perform_async('Viewed All Messages Dashboard Page', current_user.id)
  end

  def messages_to_bot
    @messages = Event.where(bot_instance_id: @instances.select(:id),
                            event_type: 'message',
                            is_for_bot: true,
                            created_at: @start.utc..@end.utc)
    @tableized = @instances.
                    select("bot_instances.*, COALESCE(users.cnt, 0) AS users_count, COALESCE(e.cnt, 0) AS events_count, e.c_at AS last_event_at").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt FROM bot_users GROUP BY bot_instance_id) users on users.bot_instance_id = bot_instances.id").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt, MAX(events.created_at) AS c_at FROM events WHERE events.event_type = 'message' AND events.is_for_bot = 't' GROUP by bot_instance_id) e ON e.bot_instance_id = bot_instances.id").
                    where("bot_instances.id IN (?)", @messages.select(:bot_instance_id)).
                    order("last_event_at DESC").
                    page(params[:page])

    @messages = GetBotInstancesCountByUnit.new(@group_by, @messages, user_time_zone: current_user.timezone).call

    TrackMixpanelEventJob.perform_async('Viewed Messages To Bot Dashboard Page', current_user.id)
  end

  def messages_from_bot
    @messages = Event.where(bot_instance_id: @instances.select(:id),
                            event_type: 'message',
                            is_from_bot: true,
                            created_at: @start.utc..@end.utc)

    @tableized = @instances.
                    select("bot_instances.*, COALESCE(users.cnt, 0) AS users_count, COALESCE(e.cnt, 0) AS events_count, e.c_at AS last_event_at").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt FROM bot_users GROUP BY bot_instance_id) users on users.bot_instance_id = bot_instances.id").
                    joins("LEFT JOIN (SELECT bot_instance_id, COUNT(*) AS cnt, MAX(events.created_at) AS c_at FROM events WHERE events.event_type = 'message' AND events.is_from_bot = 't' GROUP by bot_instance_id) e ON e.bot_instance_id = bot_instances.id").
                    where("bot_instances.id IN (?)", @messages.select(:bot_instance_id)).
                    order("last_event_at DESC").
                    page(params[:page])

    @messages = GetBotInstancesCountByUnit.new(@group_by, @messages, user_time_zone: current_user.timezone).call

    TrackMixpanelEventJob.perform_async('Viewed Messages From Bot Dashboard Page', current_user.id)
  end

  protected
  def find_instances
    if (@instances = @bot.instances.pending).count == 0
      return redirect_to(new_bot_instance_path(@bot))
    end
  end

  def init_detail_view!
    @group_by = params[:group_by].presence || 'day'
    @start, @end = GetStartEnd.new(params[:start], params[:end], current_user.timezone).call
  end

  def find_bot
    @bot = current_user.bots.find_by(uid: params[:bot_id])
    raise ActiveRecord::NotFound if @bot.blank?
  end
end
