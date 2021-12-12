namespace :translate do
  task run: :environment do
    puts '----- Storing model attributes -----'
    Rake::Task['gettext:store_model_attributes'].invoke

    puts '----- Running gettext processor -----'
    Rake::Task['gettext:find'].invoke

    puts '----- Storing translations as JSON -----'
    FastGettext.available_locales.each do |lang|
      system("bin/po2json locale/#{lang}/app.po public/locale/#{lang}.json -p")
    end
  end
end
