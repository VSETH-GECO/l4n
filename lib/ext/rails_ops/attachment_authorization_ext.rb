# Keeps ActiveStorage attachments working in rails_ops model operations.
#
# For authorization, rails_ops casts the operation's model (an extended
# `Operations::...::ModelClass`) back to the plain model class using
# `model.becomes(Upload)` etc. Since Rails 8.1, ActiveStorage overrides
# `becomes` and re-points every pending attachment change to the new object
# *in place*. The operation then saves its own model, but the attachment change
# now belongs to the throwaway authorization copy, so no blob / attachment
# records are created (the file is still uploaded to the storage service).
#
# This points the pending changes back at the operation's model after the cast.
# Remove once rails_ops handles this itself.
module RailsOpsAttachmentAuthorizationExt
  private

  def cast_model_for_authorization(model_class_or_instance)
    casted = super

    if !casted.equal?(model_class_or_instance) && model_class_or_instance.respond_to?(:attachment_changes)
      model_class_or_instance.attachment_changes.each_value do |change|
        change.record = model_class_or_instance
      end
    end

    casted
  end
end

# rubocop:disable-next Style/OneClassPerFile
class RailsOps::Operation::Model
  prepend ::RailsOpsAttachmentAuthorizationExt
end
