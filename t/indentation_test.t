use Modern::Perl;

use Archive::Extract;
use CGI;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use File::Temp qw( tempdir tempfile );
use FindBin qw($Bin);
use Module::Load::Conditional qw(can_load);
use Test::MockModule;
use Test::More qw(no_plan);
use Test::Warn;

use C4::Context;
use Koha::Database;
use Koha::Plugins::Methods;

use t::lib::Mocks;
use t::lib::TestBuilder;

use C4::Letters qw( GetQueuedMessages GetMessage );
use C4::Budgets qw( AddBudgetPeriod AddBudget GetBudget );
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Libraries;
use Koha::Patrons;
use Koha::Suggestions;
no warnings;

BEGIN {
    # Mock pluginsdir before loading Plugins module
    my $path = dirname(__FILE__) . '/../../../lib/plugins';
    t::lib::Mocks::mock_config( 'pluginsdir', $path );
    
    use_ok('C4::Suggestions', qw( NewSuggestion GetSuggestion ModSuggestion GetSuggestionInfo GetSuggestionFromBiblionumber GetSuggestionInfoFromBiblionumber GetSuggestionByStatus ConnectSuggestionAndBiblio DelSuggestion MarcRecordFromNewSuggestion GetUnprocessedSuggestions DelSuggestionsOlderThan ));
    use_ok('Koha::Plugins');
    use_ok('Koha::Plugins::Handler');
    use_ok('Koha::Plugins::Base');
}

my $schema = Koha::Database->new->schema;

# test begins

$schema->storage->txn_begin;
my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;

my $builder = t::lib::TestBuilder->new;
#Koha::Plugins::Methods->delete;
$schema->resultset('PluginData')->delete();
my $full_pm_path;

sub mock_data {
	#create a patron
	my $patron_category = $builder->build({ source => 'Category' });
	my $member = {
	    firstname => 'my firstname',
	    surname => 'my surname',
	    categorycode => $patron_category->{categorycode},
	    branchcode => 'CPL',
	    smsalertnumber => 12345,
	};
	my $member2 = {
	    firstname => 'my secondmember firstname',
	    surname => 'my secondmember surname',
	    categorycode => $patron_category->{categorycode},
	    branchcode => 'CPL',
	    email => 'to@example.com',
	};
	my $borrowernumber = Koha::Patron->new($member)->store->borrowernumber;
	my $borrowernumber2 = Koha::Patron->new($member2)->store->borrowernumber;

	#create suggestion
	my $my_suggestion_checked = {
	    title         => 'my title checked',
	    author        => 'my author checked',
	    publishercode => 'my publishercode checked',
	    suggestedby   => $borrowernumber,
	    biblionumber  => '',
	    branchcode    => 'CPL',
	    managedby     => '',
	    manageddate   => '',
	    accepteddate  => '',
	    note          => 'my note',
	    STATUS        => 'CHECKED',
	    quantity      => '', # Insert an empty string into int to catch strict SQL modes errors
	};
	my $my_suggestion = {
	    title         => 'my title',
	    author        => 'my author',
	    publishercode => 'my publishercode',
	    suggestedby   => $borrowernumber2,
	    biblionumber  => '',
	    branchcode    => 'CPL',
	    managedby     => '',
	    manageddate   => '',
	    accepteddate  => '',
	    note          => 'my note',
	    quantity      => '', # Insert an empty string into int to catch strict SQL modes errors
	};
	my $my_suggestionid = NewSuggestion($my_suggestion);
	my $suggestion = GetSuggestion($my_suggestionid);
	is( $suggestion->{title}, $my_suggestion->{title}, 'NewSuggestion stores the  correctly' );
	is( $suggestion->{STATUS}, 'ASKED', 'NewSuggestion status is ASKED' );

	my $my_suggestionid_checked = NewSuggestion($my_suggestion_checked);
	my $suggestion_checked = GetSuggestion($my_suggestionid_checked);
	is( $suggestion_checked->{title}, $my_suggestion_checked->{title}, 'checked status NewSuggestion stores the  correctly' );
	is( $suggestion_checked->{STATUS}, 'CHECKED', 'checked NewSuggestion status is checked' );
	
	return ($suggestion, $borrowernumber, $suggestion_checked, $borrowernumber2);
}


sub module_initialise {
    my $plugins_dir;
    my $module_name = 'Koha::Plugin::indentation';
    my $pm_path = 'Koha/Plugin/indentation.pm';
    my $plugins_dir1 = tempdir( CLEANUP => 1 );
    t::lib::Mocks::mock_config('pluginsdir', $plugins_dir1);
    $plugins_dir = $plugins_dir1;
    push @INC, $plugins_dir1;
    my $full_pm_path = $plugins_dir . '/' . $pm_path;
    my $ae = Archive::Extract->new( archive => "$Bin/koha-plugin-indentation-final.kpz", type => 'zip' );
    unless ( $ae->extract( to => $plugins_dir ) ) {
        warn "ERROR: " . $ae->error;
    }
    use_ok('Koha::Plugin::indentation');
    my $plugin = Koha::Plugin::indentation->new({ enable_plugins => 1});

    ok( -f $plugins_dir . "/Koha/Plugin/indentation.pm", "indentation plugin installed successfully" );
    $INC{$pm_path} = $full_pm_path;
    warning_is { Koha::Plugins->new( { enable_plugins => 1 } )->InstallPlugins(); } undef;
}

sub module_delete {
	Koha::Plugins::Handler->delete({ class => "Koha::Plugin::indentation", enable_plugins => 1 });
	my $table = "indentation_list_table";
	my $sth = C4::Context->dbh->table_info( undef, undef, $table, 'TABLE' );
	my $info = $sth->fetchall_arrayref;
	is( @$info, 0, "Table $table does no longer exist" );
    		ok( !( -f $full_pm_path ), "Koha::Plugins::Handler::delete works correctly" );
}


#--------------Use case testing starts--------------------------------------------#

#create mock data
my ($suggestion, $borrowernumber, $suggestion_checked, $borrowernumber2) = mock_data();

#initialise indentation module
module_initialise();

#print "Use case 1: cannot create indent for asked status suggestions\n";
    my $cgi = CGI->new;
    $cgi->param(-name=>'save', -value=>'0');
    local *STDOUT;
    my $stdout;
    my $stdold;
    open STDOUT, '>', \$stdout;

    Koha::Plugins::Handler->run({ class => "Koha::Plugin::indentation", method => 'tool',enable_plugins=>1, cgi=>$cgi });
    unlike($stdout, qr{my secondmember firstname my secondmember surname}, 'Use case 1: cannot display suggestor who has only pending suggestions'); 

#Use case 2: shows suggestor who has atleast one 'checked' suggestion status
    like($stdout, qr{my firstname my surname}, 'Use case 2: display suggestor who has atleast one checked suggestion');


#Use case 3: shows all 'checked' suggestions of 'selected' suggestor
    $cgi->param(-name=>'save', -value=>'!Generate indentation'); # clicked generate indentation button
    $cgi->param(-name=>'color', -value=>$borrowernumber); # selected this suggestor
    $stdout = '';
    close STDOUT;
    open STDOUT, '>', \$stdout;
    Koha::Plugins::Handler->run({ class => "Koha::Plugin::indentation", method => 'tool',enable_plugins=>1, cgi=>$cgi });
    like($stdout, qr{<td>$suggestion_checked->{author}<\/td>\n\s*<td>$suggestion_checked->{title}<\/td>\n\s*<td>$suggestion_checked->{publicationyear}<\/td>\n\s*<td>$suggestion_checked->{publishercode}<\/td>\n\s*<td>$suggestion_checked->{price}<\/td>\n\s*<td>$suggestion_checked->{currency}<\/td>\n\s*<td><\/td>\n\s*<td>$suggestion_checked->{quantity}<\/td>}, 'Use case 3: display checked suggestions for pdf indent of choosen suggestor');

#Use case 4: displays correct indentation id format when indentid left blank
    $cgi->param(-name=>'indentid', -value=>''); #indentid left blank
    $cgi->param(-name=>'date', -value=>'2020-12-12'); #input date (optional)
    $cgi->param(-name=>'department', -value=>'cse'); #input department (optional)
    $cgi->param(-name=>'save', -value=>'Generate indentation'); #clicked 'generate pdf' button
    $stdout = '';
    close STDOUT;
    open STDOUT, '>', \$stdout;
    Koha::Plugins::Handler->run({ class => "Koha::Plugin::indentation", method => 'tool',enable_plugins=>1, cgi=>$cgi });
    like($stdout, qr{LIB-20-cse-1001}, 'Use case 4: displays correct indentid format when indentid left blank');

#Use case 5: displays correct indentation id format when indentid given
    $cgi->param(-name=>'indentid', -value=>'1234'); #input custom indentid 
    $cgi->param(-name=>'date', -value=>'2020-12-12'); #input date (optional)
    $cgi->param(-name=>'department', -value=>'cse'); #input department (optional)
    $cgi->param(-name=>'save', -value=>'Generate indentation'); #clicked 'generate pdf' button
    $stdout = '';
    close STDOUT;
    open STDOUT, '>', \$stdout;
    Koha::Plugins::Handler->run({ class => "Koha::Plugin::indentation", method => 'tool',enable_plugins=>1, cgi=>$cgi });
    like($stdout, qr{LIB-20-cse-1234}, 'Use case 5: displays correct indentid format when indentid given');

#Use case 6: popup window for pdf generation after filling in details
    $cgi->param(-name=>'indentid', -value=>'5678'); #input custom indentid 
    $cgi->param(-name=>'date', -value=>'2020-12-12'); #input date (optional)
    $cgi->param(-name=>'department', -value=>'cse'); #input department (optional)
    $cgi->param(-name=>'save', -value=>'Generate indentation'); #clicked 'generate pdf' button
    $stdout = '';
    close STDOUT;
    open STDOUT, '>', \$stdout;
    Koha::Plugins::Handler->run({ class => "Koha::Plugin::indentation", method => 'tool',enable_plugins=>1, cgi=>$cgi });
    like($stdout, qr{var sTable = document.getElementById\('tab'\).innerHTML;\s*var sImage = document.getElementById\('taghead'\).innerHTML;}, 'Use case 6: popup window for pdf generation after filing in details');


#uninstall indentation module
module_delete();



    

$schema->storage->txn_rollback();
