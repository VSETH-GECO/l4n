module TournamentHelper
  def format_match_score(match, relevant_team)
    if match.draw?
      tag.span(class: 'text-warning') do
        'D'
      end
    elsif match.winner.blank?
      '&mdash;'.html_safe
    elsif match.winner_id == relevant_team&.id
      tag.span(class: 'text-success') do
        'W'
      end
    else
      tag.span(class: 'text-danger') do
        'L'
      end
    end
  end

  def format_match_score_large(match, relevant_team)
    if match.draw?
      tag.div(class: 'bg-warning text-white result-score-box') do
        _('Match|Draw')
      end
    elsif match.winner.blank?
      tag.div(class: 'bg-secondary text-white result-score-box') do
        _('Match|Tbd')
      end
    elsif match.winner_id == relevant_team&.id
      tag.div(class: 'bg-success text-white result-score-box') do
        _('Match|Winner')
      end
    else
      tag.div(class: 'bg-danger text-white result-score-box') do
        _('Match|Loser')
      end
    end
  end

  def round_matches_to_inverse_round_index_word(number_of_matches)
    case number_of_matches
    when 2
      'one'
    when 4
      'two'
    when 8
      'three'
    when 16
      'four'
    when 32
      'five'
    when 64
      'six'
    else
      ''
    end
  end
end
