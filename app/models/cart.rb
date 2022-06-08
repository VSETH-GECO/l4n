class Cart < ApplicationRecord
  # == Attributes ==================================================================

  # == Constants ===================================================================

  # == Associations ================================================================
  belongs_to :user
  has_many :cart_items, dependent: :destroy

  # == Validations =================================================================
  validates :user, uniqueness: true

  # == Hooks =======================================================================

  # == Scopes ======================================================================

  # == Class Methods ===============================================================

  # == Instance Methods ============================================================
  def item_count
    cart_items.sum(:quantity)
  end

  def total
    cart_items.sum(Money.zero, &:total)
  end

  # == Private Methods =============================================================
end
