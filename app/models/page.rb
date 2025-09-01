class Page < ApplicationRecord
  # Associations
  has_one :app_project, foreign_key: "generated_marketing_page_id", dependent: :nullify

  # Validations
  validates :title, presence: true, uniqueness: true, length: { minimum: 5, maximum: 150 }
  validates :content, presence: true
end
