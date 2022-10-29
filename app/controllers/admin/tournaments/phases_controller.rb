module Admin
  module Tournaments
    class PhasesController < AdminController
      add_breadcrumb _('Admin|Tournaments'), :admin_tournaments_path

      def show
        op Operations::Admin::Tournament::Phase::Load
        add_breadcrumb model.tournament.name, admin_tournament_path(model.tournament)
        add_breadcrumb "#{model.phase_number}. #{model.name}"
      end

      def new
        op Operations::Admin::Tournament::Phase::CreateForTournament
        add_breadcrumb op.tournament.name, admin_tournament_path(op.tournament)
        add_breadcrumb _('Admin|Tournament|Phase|New')
      end

      def create
        if run Operations::Admin::Tournament::Phase::CreateForTournament
          flash[:success] = _('Admin|Tournament|Phase|Successfully created')
          redirect_to admin_tournament_path(op.tournament)
        else
          add_breadcrumb op.tournament.name, admin_tournament_path(op.tournament)
          add_breadcrumb _('Admin|Tournament|Phase|New')
          flash[:danger] = _('Admin|Tournament|Phase|Create failed')
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        op Operations::Admin::Tournament::Phase::Update
        add_breadcrumb model.tournament.name, admin_tournament_path(model.tournament)
        add_breadcrumb model.name
      end

      def update
        if run Operations::Admin::Tournament::Phase::Update
          flash[:success] = _('Admin|Tournament|Phase|Successfully updated')
          redirect_to admin_tournament_path(model.tournament)
        else
          add_breadcrumb model.tournament.name, admin_tournament_path(model.tournament)
          add_breadcrumb model.name
          flash[:danger] = _('Admin|Tournament|Phase|Update failed')
          render :new, status: :unprocessable_entity
        end
      end

      def destroy
        if run Operations::Admin::Tournament::Phase::Destroy
          flash[:success] = _('Admin|Tournament|Phase|Successfully destroyed')
        else
          flash[:danger] = _('Admin|Tournament|Phase|Could not be destroyed')
        end

        redirect_to admin_tournament_path(model.tournament)
      end

      def generate_rounds
        if run Operations::Admin::Tournament::Phase::GenerateRounds
          flash[:success] = _('Admin|Tournament|Phase|Successfully generated rounds')
        else
          flash[:danger] = _('Admin|Tournament|Phase|Generating rounds failed')
        end
      rescue Operations::Exceptions::OpFailed => e
        flash[:danger] = e.message
      ensure
        redirect_to admin_phase_path(model)
      end

      def update_seeding
        if run Operations::Admin::Tournament::Phase::UpdateSeeding
          flash[:success] = _('Admin|Tournament|Phase|Successfully updated seeding')
        else
          flash[:danger] = _('Admin|Tournament|Phase|Failed to update seeding')
        end
        redirect_to admin_phase_path(model)
      end

      def confirm_seeding
        if run Operations::Admin::Tournament::Phase::ConfirmSeeding
          flash[:success] = _('Admin|Tournament|Phase|Successfully confirmed seeding')
        else
          flash[:danger] = _('Admin|Tournament|Phase|Failed to confirm seeding')
        end
        redirect_to admin_phase_path(model)
      end

      def generate_next_round_matches
        if run Operations::Admin::Tournament::Phase::GenerateNextRoundMatches
          flash[:success] = _('Admin|Tournament|Phase|Successfully generated next round matches')
        else
          flash[:danger] = _('Admin|Tournament|Phase|Failed to generate next round matches')
        end
      rescue Operations::Exceptions::OpFailed => e
        flash[:danger] = e.message
      ensure
        redirect_to admin_phase_path(model)
      end

      def complete
        if run Operations::Admin::Tournament::Phase::Complete
          flash[:success] = _('Admin|Tournament|Phase|Successfully completed the phase')
        else
          flash[:danger] = _('Admin|Tournament|Phase|Failed to complete the phase')
        end
      rescue Operations::Exceptions::OpFailed => e
        flash[:danger] = e.message
      ensure
        redirect_to admin_phase_path(model)
      end
    end
  end
end
