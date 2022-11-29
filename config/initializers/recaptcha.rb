unless Rails.env.test? || Figaro.env.building_docker_image
  Recaptcha.configure do |config|
    config.site_key = Figaro.env.recaptcha_site_key!
    config.secret_key = Figaro.env.recaptcha_site_secret!
  end
end
