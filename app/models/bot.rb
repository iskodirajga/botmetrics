class Bot < ActiveRecord::Base
  include WithUidUniqueness

  validates_presence_of  :name, :provider

  PROVIDERS = {
    'facebook' => true,
    'slack' => true,
    'kik' => true,
    'telegram' => false,
    'amazon' => false
  }

  validates_inclusion_of :provider, in: PROVIDERS.keys
  validates_format_of    :webhook_url, with: %r(\Ahttps://), if: ->(record) { record.webhook_url.present? }

  has_many :instances, class_name: 'BotInstance'

  has_many :bot_collaborators
  has_many :collaborators, through: :bot_collaborators, source: :user
  has_many :owners, -> { where("bot_collaborators.collaborator_type" => 'owner') }, through: :bot_collaborators, source: :user

  has_many :notifications
  has_many :webhook_events
  has_many :dashboards

  def build_instance(params)
    instance = instances.find_by(provider: provider)
    if instance.present? && instance.provider != 'slack'
      return instance.assign_attributes(params) || instance
    end
    instances.build(params)
  end

  def events
    Event.where(bot_instance_id: self.instances.select(:id))
  end

  def create_default_dashboards_with!(owner)
    Dashboard.const_get(:"DEFAULT_#{self.provider.upcase}_DASHBOARDS").each do |type|
      self.dashboards.create!(
        name: type.titleize,
        dashboard_type: type,
        bot: self,
        user: owner,
        provider: self.provider,
        default: true
      )
    end
  end
end
