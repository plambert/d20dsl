use Modern::Perl qw/2012/;
use Test::More skip_all => 'Refactoring these tests away';
use Carp::Always;
use Test::LongString;
use ORC;

our $orc;


my @orc_parse_tests=(
  "7;",
  "7;\n",
  "1;\n\n2;\n\n\n",
  "c=9+3;\n",
  "c=9+3; c;",
  "c=9+3;\n c ;\n",
  "c=9+3;y=c*2+1; y;",
  "a=1d6;",
  "1d6;",
  "3d6;",
  "4d6d1;",
);

my @orc_value_tests=(
  "[[EXPECT 1]]print 1;\n",
  "[[EXPECT 7]]print 7;",
  "[[EXPECT 2]]print 1+1;",
  "[[EXPECT 7]]print 1+2*3;",
  "[[EXPECT 7]]a=7;print a;",
  "[[EXPECT 9]]print 3d6;",
  "[[EXPECT 9]]print 3d6;",
  "[[EXPECT 8]]print 1d6+1d6;",
  "[[EXPECT 11]]print 4d6d1;",
);

subtest 'Basic module loading' => sub {
  plan tests => 2;
  can_ok('ORC', 'new');
  $orc=ORC->new;
  isa_ok($orc, "ORC");
};

subtest 'Parsing tests' => sub {
  plan tests => scalar(@orc_parse_tests);
  orc_parse_test(@orc_parse_tests);
};

subtest 'Value tests' => sub {
  plan tests => scalar(@orc_value_tests);
  orc_value_test(@orc_value_tests);
};

sub orc_parse_test {
  my ($string, $opts, $result, $parse_result);
  my $index=1;
  while(@_) {
    ($string, $opts)=determine_test(shift, name_pattern => "parse '%f'");
    subtest $index . ": [" . flatten_string($string) . "]" => sub {
      local $TODO = $opts->{todo} if (defined($opts->{todo}));
      $parse_result=$orc->parse($string);
      if (!defined($parse_result)) {
        $result='UNDEF';
      }
      elsif (ref $parse_result and $parse_result->can('prettyprint')) {
        $result=$parse_result->prettyprint;
      }
      else {
        $result="$parse_result";
      }
      if ($opts->{fail}) {
        isnt($result, $string, "parse: " . flatten_string($string)) or diag("returned: ", $parse_result);
      }
      else {
        is_string_nows($result, $string, "parse: " . flatten_string($string)) or diag("returned: ", $parse_result);
      }
    };
    $index++;
  }
}

sub orc_value_test {
  my $index=1;
  while(@_ > 0) {
    my ($string, $opts) = determine_test(shift);
    # my ($string, $expected) = (shift, shift);
    subtest $index . ": [" . flatten_string($string) . "]" => sub {
      local $TODO = $opts->{todo} if ($opts->{todo});
      plan tests => 3;
      srand(42);
      ok(my $parsed=$orc->parse($string), "Random test #" . $index. " parses correctly");
      isa_ok($parsed, "ORC::Script", "Parsed script is an ORC script");
      is(0+$parsed->do, $opts->{expect}, "Random test #" . $index . " returns " . $opts->{expect});
    };
    $index++;
  }
}

sub flatten_string {
  my $s=shift;
  $s=~s{\G([^\\\n\r\t]+)|(\\.)|(\n)|(\r)|(\t)|(\\)}{defined($1) ? $1 : ($2 ? $2 : $3 ? "\\n" : $4 ? "\\r" : $5 ? "\\t" : "\\")}eg;
  return $s;
}

sub compress_whitespace {
  my $s=shift;
  $s=~s{\s+}{}g;
  return $s;
}

sub determine_test {
  my $test_spec=shift;
  my $string;
  my $opts={};
  if ($_[0] and ref $_[0] eq 'HASH') {
    $opts=shift;
  }
  else {
    while(@_>1) {
      my ($k, $v) = (shift, shift);
      $opts->{$k}=$v;
    }
  }
  if (ref $test_spec eq 'ARRAY') {
    $string=shift @$test_spec;
    if (ref $test_spec->[0] eq 'HASH') {
      $opts=$test_spec->[0];
    }
    else {
      while(@$test_spec) {
        $opts->{shift @$test_spec} = shift @$test_spec;
      }
    }
  }
  elsif (ref $test_spec eq 'HASH') {
    $string = $test_spec->{script} || die "test spec hash must include a 'script' value";
    $opts->{$_}=$test_spec->{$_} for (grep { $_ ne 'test' } (keys %$test_spec));
  }
  elsif (!ref $test_spec) {
    while($test_spec =~ s{^\[\[(.*?)\]\]}{}) {
      my $opt_string=$1;
      if ($opt_string =~ m{^TODO:(.*)$}) {
        $opts->{todo}=$1;
      }
      elsif ($opt_string =~ m{^(\!|FAIL|NOT[_-]?OK)$}) {
        $opts->{fail}=1;
      }
      elsif ($opt_string =~ m{^(OK|SUCCEED)$}) {
        delete $opts->{fail} if (exists $opts->{fail});
      }
      elsif ($opt_string =~ m{^(?:=|IS:?\s+|MATCH:?\s+|EXPECT(?:ED|ING)?:?\s+)(.*)$}) {
        $opts->{expect}=$1;
      }
      elsif ($opt_string =~ m{^(?:NOMATCH|NOEXPECT|PARSE(?:[_-]?ONLY)?|\*)$}) {
        delete $opts->{expect} if (exists $opts->{expect});
      }
      else {
        die "unknown option string '${opt_string}'";
      }
    }
    $string=$test_spec;
  }
  else {
    die "unknown test spec type: ${test_spec}";
  }
  if (!$opts->{name}) {
    my $name=$opts->{name_pattern} // "script: '%f'";
    $name =~ s{%(.)}{
      my $key=$1;
      if ($key eq 'f') {
        flatten_string($string // "UNNAMED TEST");
      }
      elsif ($key eq 's') {
        $string;
      }
      elsif ($key eq '%') {
        "%";
      }
      else {
        die sprintf("unexpected substitution '%%%s' in '%s'", $key, $opts->{name_pattern});
      }
    }eg;
    $opts->{name}=$name;
  }
  return ($string, $opts);
}

done_testing;
