module Operations::Admin::Product
  class Update < RailsOps::Operation::Model::Update
    schema do
      req :id
      opt :product do
        opt :name
        opt :on_sale
        opt :description
        opt :inventory
        opt :enabled_product_behaviours
        opt :images
        opt :remove_images
        opt :product_variants_attributes
      end
    end

    model ::Product do
      attribute :remove_images
    end

    def perform
      # TODO: handle case when availability would fall under zero
      difference = model.inventory - model.inventory_was
      model.availability += difference

      super

      osparams.product[:remove_images]&.each do |id_to_remove|
        model.images.find(id_to_remove).purge
      end
    end
  end
end
