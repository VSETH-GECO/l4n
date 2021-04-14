module ApplicationHelper
  def flash_messages(_opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, message, class: "alert alert-#{msg_type} alert-dismissible fade show notification-flash", role: 'alert') do
               concat content_tag(:button, '<span aria-hidden="true">&times;</span>'.html_safe, class: 'close', data: { 'dismiss': 'alert' })
               concat message
             end)
    end
    nil
  end

  def dark_mode_class
    # rubocop:disable Lint/LiteralAsCondition
    'dark-mode' if false
    # rubocop:enable Lint/LiteralAsCondition
  end
end
