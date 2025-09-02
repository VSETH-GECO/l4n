PayrexxPayment::Engine.routes.draw do
  get :/, to: 'payment#index', as: :start_payment

  post :pay, to: 'payment#complete_payment', as: :complete_payment
  get :success, to: 'payment#success', as: :success_payment
  get :failure, to: 'payment#failure', as: :failure_payment
  get :cancel, to: 'payment#failure', as: :cancel_payment
end
