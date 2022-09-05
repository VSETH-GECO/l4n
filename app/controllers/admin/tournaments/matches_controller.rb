module Admin
  module Tournaments
    class MatchesController < AdminController
      add_breadcrumb _('Admin|Tournaments'), :admin_tournaments_path

      def show
        op Operations::Admin::Tournament::Match::Load
        add_breadcrumb model.phase.tournament.name, admin_tournament_path(model.phase.tournament)
        add_breadcrumb "#{model.phase.phase_number}. #{model.phase.name}", admin_phase_path(model.phase)
        add_breadcrumb _('Admin|Match')
      end

      def update
        if run Operations::Admin::Tournament::Match::Update
          flash[:success] = _('Admin|Tournaments|Match|Successfully updated')
        else
          flash[:danger] = _('Admin|Tournamens|Match|Update failed')
        end
      rescue MatchNotInRunningPhase
        flash[:danger] = _('Admin|Tournamens|Match|Not in running phase')
      rescue MatchNotInCurrentRound
        flash[:danger] = _('Admin|Tournamens|Match|Not in current round')
      ensure
        redirect_to admin_match_path(model)
      end
    end
  end
end
