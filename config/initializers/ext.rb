# rubocop:disable-next Rails/RootPathnameMethods
Dir.glob(Rails.root.join('lib/ext/**/*.rb')).each do |filename|
  require filename
end
