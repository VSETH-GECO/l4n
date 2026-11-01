require 'httparty'

module Operations::User::Discord
  class AddGuildMemberRole < RailsOps::Operation
    schema3 do
      int! :id, cast_str: true
      int! :discord_guild_id, cast_str: true
      int! :discord_role_id, cast_str: true
    end

    policy :on_init do
      authorize! :read_public, user
    end

    attr_accessor :data
    attr_accessor :successful

    def perform
      if user.discord_id.blank?
        @successful = false
        return
      end

      if Figaro.env.discord_bot_auth.blank?
        @successful = false
        return
      end

      response = HTTParty.put("https://discordapp.com/api/guilds/#{osparams.discord_guild_id}/members/#{user.discord_id}/roles/#{osparams.discord_role_id}", headers: { 'Authorization' => Figaro.env.discord_bot_auth! })

      if response.code == 200
        @successful = true
        @data = response
      else
        @successful = false
      end
    end

    private

    def user
      @user ||= ::User.find(osparams.id)
    end
  end
end
