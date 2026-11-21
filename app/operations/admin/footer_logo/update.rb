module Operations::Admin::FooterLogo
  class Update < RailsOps::Operation::Model::Update
    schema3 do
      int! :id, cast_str: true
      hsh? :footer_logo do
        str? :sort
        str? :visible
        obj? :file
        obj? :file_dark
        str? :remove_file_dark
        str? :link
      end
    end

    model ::FooterLogo do
      attribute :remove_file_dark, :boolean
    end

    def perform
      super

      return unless model.valid?

      model.file_dark.purge if model.remove_file_dark && model.file_dark.attached?
    end
  end
end
