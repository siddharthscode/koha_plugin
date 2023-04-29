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


our $VERSION = "3.0";

our $metadata = {
    name            => 'Indentation plugin',
    author          => 'Siddharth, Rewant, Nisha, Sravanthi',
    description     => 'Generate indentation',
    date_authored   => '2023-04-07',
    date_updated    => "2023-04-29",
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
            # my $indentation_id = "LIB-23-LA-2269";
            my $table = "indentation_list_table";
            my $indentid =  $cgi->param('indentid');
            my $dateid = $cgi->param('date');
            my $departmentid = $cgi->param('department');

            my ($Y, $M, $D) = split(/-/, $dateid);
            if ($indentid eq "")
            {
            	my $defaultValue = 1000;
                my $qq10 = "SELECT IFNULL(MAX(indentno), $defaultValue) as lastIndentNo FROM $table";
                my $dbh10 = C4::Context->dbh;
                my $sth30 = $dbh10->prepare($qq10);
                $sth30->execute();
                my $lastIndent = $sth30->fetchrow_hashref();
                $indentid = $lastIndent->{lastIndentNo};
                $indentid++;
                # $indentid = "LIB-".$Y."-".$departmentid."-$currentIndent";
            }
            my $year = $Y % 100;
            my $indentation = "LIB-".$year."-".$departmentid."-".$indentid;
            foreach my $row ( @suggest_list){
                my $dbh11 = C4::Context->dbh;
                my $qq11 = qq/
                            INSERT INTO $table (indentationid, indentno, indentyear, indentdepartment, status, suggestionid) 
                            VALUES (?, ?, ?, ?, ?, ?)/;
                my $sth31 = $dbh11->prepare($qq11);
                $sth31->execute($indentation, $indentid, $year, $departmentid, 'indentation generated', $row->{suggestionid});
                $sth31->finish();
            }  
            
            my $template1 = $self->get_template({ file => 'tool-step3.tt' });
            $template1->param(borrower => $rr1, 
                              words => \@suggest_list,
                              indent_id => $indentation,
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
        `indentno` INT NOT NULL,
        `indentyear` INT NOT NULL,
        `indentdepartment` VARCHAR(4) NOT NULL,
        `status` VARCHAR(50) DEFAULT 'pending',
        `suggestionid` INT(10) DEFAULT NULL
        ) ENGINE = INNODB;";
    $dbh1->{PrintError} = 1;
    $dbh1->{RaiseError} = 1;
    my $sth3 = $dbh1->prepare($qq1);
    $sth3->execute() or die "unable to execute".$sth3->errstr();
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
