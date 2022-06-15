class PromotionCode < ApplicationRecord
  # == Attributes ==================================================================

  # == Constants ===================================================================

  # == Associations ================================================================
  belongs_to :promotion
  has_one :promotion_code_mapping, dependent: :destroy
  delegate :order, to: :promotion_code_mapping, allow_nil: true

  # == Validations =================================================================
  validates :code, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }

  # == Hooks =======================================================================
  before_destroy :ensure_not_used

  # == Scopes ======================================================================

  # == Class Methods ===============================================================

  # == Instance Methods ============================================================

  # == Private Methods =============================================================
  private

  def ensure_not_used
    return if promotion_code_mapping.order.blank?

    fail ActiveRecord::RecordNotDestroyed, _('PromotionCode|Cannot be deleted, as it has been used')
  end
end
