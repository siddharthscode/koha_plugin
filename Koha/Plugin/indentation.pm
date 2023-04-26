package Koha::Plugin::indentation;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Auth;
use C4::Context;

use Koha::Account::Lines;
use Koha::Account;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::Patron;

use Cwd qw(abs_path);
use Data::Dumper;
use LWP::UserAgent;
use MARC::Record;
use Mojo::JSON qw(decode_json);;
use URI::Escape qw(uri_unescape);


our $VERSION = "2.2";

our $metadata = {
    name            => 'Indentation plugin',
    author          => 'Siddharth, Rewant, Sravanthi, Nisha',
    description     => 'Generate indentation',
    date_authored   => '2023-04-07',
    date_updated    => "2023-04-26",
    minimum_version => '19.1100000',
    maximum_version => undef,
    version         => $VERSION,
};


sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    my $self = $class->SUPER::new($args);

    return $self;
}

sub report {
    my ( $self, $args ) = @_;
    
    my $cgi = $self->{'cgi'};
    my $template = $self->get_template({ file => 'tool-step2.tt' });

    $self->output_html($template->output());
}

sub tool {
    
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    unless ($cgi->param('save')){
        my $template = $self->get_template({ file => 'tool-step2.tt' });
        my $dbh = C4::Context->dbh;

        # find all borrowers who suggested
        my $suggestors_query = "
            SELECT DISTINCT borrowers.firstname, borrowers.surname, borrowers.borrowernumber
            FROM suggestions, borrowers 
            WHERE suggestions.suggestedby LIKE borrowers.borrowernumber
            AND suggestions.STATUS LIKE 'CHECKED'
        ";
        my $sth = $dbh->prepare($suggestors_query);
        $sth->execute();
        my @suggestors_id_list;
        while ( my $row = $sth->fetchrow_hashref() ) {
            push( @suggestors_id_list, $row );
        }
        $template->param( suggestor_list => \@suggestors_id_list);
        $self->output_html($template->output());
    }
    else{
        my $borrow_id = scalar $cgi->param('color');
        my $dbh = C4::Context->dbh;
        my $borrow_query = "
        SELECT * FROM suggestions  
        WHERE suggestedby LIKE '$borrow_id' 
        AND STATUS LIKE 'CHECKED' ";
        my $sth2 = $dbh->prepare($borrow_query);
        $sth2->execute();
        my @suggest_list;
        while ( my $row = $sth2->fetchrow_hashref() ) {
            push( @suggest_list, $row );
        }
        my $dbh1 = C4::Context->dbh;
        my $qq1 = "SELECT * FROM borrowers  WHERE borrowernumber LIKE '$borrow_id' ";
        my $sth3 = $dbh1->prepare($qq1);
        $sth3->execute();
        my $rr1 = $sth3->fetchrow_hashref();
        my @departments;
        push(@departments, "CSE");
        push(@departments, "AI");
        push(@departments, "MA");
        push(@departments, "EE");

        unless ($cgi->param('save') eq 'Generate indentation'){
            my $template = $self->get_template({ file => 'tool-step1.tt' });
            $template->param(borrower => $rr1,                 
                            departments => \@departments,
                            words => \@suggest_list);
            $self->output_html($template->output());
        }
        else{
             #-----------------------new part----------------------------------------------------------------------------#
            #add indentation of this borrower in database
            #for now there is a dummy indentation id
            #my $indentation_id = "LIB-23-LA-2269";
            my $table = "indentation_list_table";
            my $indentid =  $cgi->param('indentid');
            my $dateid = $cgi->param('date');
            my $departmentid = $cgi->param('department');

            my ($Y, $M, $D) = split(/-/, $dateid);
            if ($indentid eq "")
            {
                my $qq10 = "SELECT indentationid FROM $table ORDER BY indentationid DESC LIMIT 1";
                my $dbh10 = C4::Context->dbh;
                my $sth30 = $dbh10->prepare($qq10);
                $sth30->execute();
                my $lastIndent = $sth3->fetchrow_hashref();
                if ($lastIndent eq "")
                {
                    $lastIndent = "1000";
                }
                my $currentIndent = $lastIndent + "0001";
                $indentid = "LIB-".$Y."-".$departmentid."-$currentIndent";
            }

            foreach my $row ( @suggest_list){
                my $dbh11 = C4::Context->dbh;
                my $qq11 = qq/
                            INSERT INTO $table (indentationid, status, suggestionid) 
                            VALUES (?, ?, ?)/;
                my $sth31 = $dbh11->prepare($qq11);
                $sth31->execute($indentid, 'indentation generated', $row->{suggestionid});
                $sth31->finish();
            }  
            
            my $template1 = $self->get_template({ file => 'tool-step3.tt' });
            $template1->param(borrower => $rr1, 
                              words => \@suggest_list,
                              indent_id => $indentid,
                              date_id => $dateid,
                              department_id => $departmentid);
            $self->output_html($template1->output());            
        }
    }
}


sub configure {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};
}

sub install() {
    my ( $self, $args ) = @_;
    my $indentation_table = "indentation_list_table";
	
	#-------install and uninstall operations are working correctly-----------#
    my $dbh1 = C4::Context->dbh;
   my $qq1 = "
         CREATE TABLE IF NOT EXISTS $indentation_table (
         `indentationid` VARCHAR(50) NOT NULL,
         `status` VARCHAR(50) DEFAULT 'pending',
          `suggestionid` INT(10) DEFAULT NULL
        ) ENGINE = INNODB;";
    print "test12";
    $dbh1->{PrintError} = 1;
    $dbh1->{RaiseError} = 1;
    my $sth3 = $dbh1->prepare($qq1);
    print $dbh1;
    print "test2";
    $sth3->execute() or die "unable to execute".$sth3->errstr();
    print "test3";
    $sth3->finish();
    
    return 1;
}

sub uninstall() {
    my ( $self, $args ) = @_;
    my $table = "indentation_list_table";

    my $dbh1 = C4::Context->dbh;
    my $qq1 = "DROP TABLE IF EXISTS $table";
    my $sth3 = $dbh1->prepare($qq1);
    $sth3->execute();
    $sth3->finish();

    return 1;
}

# sub tool_step1{
#     my ( $self, $args ) = @_;
#     my $cgi = $self->{'cgi'};
#     my $template = $self->get_template({ file => 'tool-step1.tt' });
#     my $dbh = C4::Context->dbh;
#     # my $suggestions_table = $self->get_qualified_table_name('suggestions');

#     # my $words = $dbh->selectcol_arrayref( "SELECT fancy_word FROM $suggestions_table" );
#     $template->param( words => ['demo', 'demo2'] ,);
#     $self->output_html( $template->output() );
# }
