use strict;
use Text::CSV;

my $csv = Text::CSV->new({ sep_char => ',' });
my $file = $ARGV[0] || die "USAGE: <football stats csv file>\n";

# Assume csv file is ordered by date. Count run length for each team. 
# Based on the team's next win/loss add an entry to runs[<run length>].
# teamRunLength{<team name>} -> <run length>
# runStats{<run length>} -> [<number of wins>, <n>]

my %teamRunLength;
my %teamHasLoss;
my %runStats;

open(my $data, '<', $file) or die "Could not open '$file' $!\n";
my %p = getColPos();
my $prevDate;
my $prevScheduleYear;
while (my @fields = getFields()) {
  my $scheduleYear = $fields[$p{schedule_season}];
  if ($scheduleYear ne $prevScheduleYear) {
    %teamRunLength = {};
    %teamHasLoss = {};
    $prevScheduleYear = $scheduleYear;
  }
  
  my $homeTeam = $fields[$p{team_home}];
  my $awayTeam = $fields[$p{team_away}];
  my $homeScore = $fields[$p{score_home}];
  my $awayScore = $fields[$p{score_away}];
  next if (!$homeScore && !$awayScore);

  my $date = $fields[$p{schedule_date}];
  if ($date ne $prevDate) {
    print STDERR "$date...\n";
    $prevDate = $date;
  }

  my $homeRunLength = $teamRunLength{$homeTeam} || 0;
  my $awayRunLength = $teamRunLength{$awayTeam} || 0;
  my $homeHasLoss = $teamHasLoss{$homeTeam} || 0;
  my $awayHasLoss = $teamHasLoss{$awayTeam} || 0;

  if ($homeScore == $awayScore) {
    next;
  } elsif ($homeScore > $awayScore) {
    $teamRunLength{$homeTeam} = $homeRunLength + 1;
    $teamRunLength{$awayTeam} = 0;
    $teamHasLoss{$awayTeam} = 1;
    if (!$homeHasLoss) { addStats($homeRunLength, 1); }
    if (!$awayHasLoss) { addStats($awayRunLength, 0); }
  } else {
    $teamRunLength{$awayTeam} = $awayRunLength + 1;
    $teamRunLength{$homeTeam} = 0;
    $teamHasLoss{$homeTeam} = 1;
    if (!$homeHasLoss) { addStats($homeRunLength, 0); }
    if (!$awayHasLoss) { addStats($awayRunLength, 1); }
  }
}

foreach my $run (sort {$a <=> $b} keys(%runStats)) {
  my $win = $runStats{$run}[0] / $runStats{$run}[1];
  printf STDOUT ("\%2d: \%0.2f (%d)\n", $run, $win, $runStats{$run}[1]);
}

exit 0;


sub getFields {
  my $line = <$data>;
  if (!$line) { return (); }

  chomp $line;
  if (!$csv->parse($line)) { die "Can't parse line: $line"; }
  return $csv->fields();
}

sub getColPos {
  my @fields = getFields();
  my %colPos;
  for (my $i=0 ; $i < scalar(@fields) ; ++$i) {
    $colPos{$fields[$i]} = $i;
  }
  return %colPos;
}

sub addStats {
  my ($run, $win) = @_;

  if (!$runStats{$run}) { @{$runStats{$run}} = (0, 0); }
  $runStats{$run}[0] += $win;
  $runStats{$run}[1]++;
}
