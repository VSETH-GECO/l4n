if Rails.env.development?
  Figaro.require_keys(%w[
                        payrexx_api_key
                      ])
end
