module Operations::Admin::FooterLogo
  class Create < RailsOps::Operation::Model::Create
    schema3 do
      hsh? :footer_logo do
        str? :sort
        str? :visible
        obj? :file
        obj? :file_dark
        str? :link
      end
    end

    model ::FooterLogo
  end
end
