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


our $VERSION = "{VERSION}";

our $metadata = {
    name            => 'Indentation plugin',
    author          => 'Siddharth',
    description     => 'Generate indentation',
    date_authored   => '2020-12-01',
    date_updated    => "1970-01-01",
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
        ";
        my $sth = $dbh->prepare($suggestors_query);
        $sth->execute();
        my @suggestors_id_list;
        while ( my $row = $sth->fetchrow_hashref() ) {
            push( @suggestors_id_list, $row );
        }
        $template->param( suggestor_list => \@suggestors_id_list);
        $self->output_html($template->output());

        # my @suggestor_list;
        # while (my ($borrowernumber) = each @suggestors_id_list){
        #     # my ($borrowernumber, $firstname, $surname) = @borrow;
        #     my $qq = "
        #         SELECT *  FROM borrowers WHERE borrowernumber LIKE '$borrowernumber'
        #     ";
        #     my $sth1 = $dbh->prepare($qq);
        #     $sth1->execute();
        #     while ( my $row = $sth1->fetchrow_hashref() ) {
        #         push( @suggestor_list, $row );
        #     }
        # }
        # $template->param( suggestor_list => \@suggestor_list);

        # $self->output_html($template->output());

    }
    else{
        my $borrow_id = scalar $cgi->param('color');
        my $template = $self->get_template({ file => 'tool-step1.tt' });
        my $dbh = C4::Context->dbh;

    #     # find all borrowers
    #     my $borrowers_query = "
    #         SELECT borrowernumber FROM borrowers
    #     ";
    #     my $sth = $dbh->prepare($borrowers_query);
    #     $sth->execute();
    #     my @borrowers_list;
    #     while ( my $row = $sth->fetchrow_array() ) {
    #         push( @borrowers_list, $row );
    #     }

    #     # $template->param(words => \@borrowers_list);
    #     # $self->output_html($template->output());
    #     #check if a borrower has a suggestion
    #     while (my $borrowernumber = each @borrowers_list){
    #         # my ($borrowernumber, $firstname, $surname) = @borrow;
            my $borrow_query = "SELECT * FROM suggestions  WHERE suggestedby LIKE '$borrow_id' ";
            my $sth2 = $dbh->prepare($borrow_query);
            $sth2->execute();
            my @suggest_list;
            while ( my $row = $sth2->fetchrow_hashref() ) {
                push( @suggest_list, $row );
            }

    #         if(@suggest_list){
    #             #if list is not empty
    #             $template->param(words => \@suggest_list,
    #                             borrower => scalar Koha::Patrons->find($borrowernumber));
    #             # print $template->output();
                my $dbh1 = C4::Context->dbh;
                my $qq1 = "SELECT * FROM borrowers  WHERE borrowernumber LIKE '$borrow_id' ";
                my $sth3 = $dbh1->prepare($qq1);
                $sth3->execute();
                my $rr1 = $sth3->fetchrow_hashref();
                $template->param(borrower => $rr1, 
                                words => \@suggest_list);
                $self->output_html($template->output());
    #             q|
    #         <script>
    #         var button = document.getElementById("pdfButton");
    #     var makepdf = document.getElementById("generatePDF");
    #     button.addEventListener("click", function () {
    #         var mywindow = window.open("", "PRINT", "height=600,width=600");
    #         mywindow.document.write(makepdf.innerHTML);
    #         mywindow.document.close();
    #         mywindow.focus();
    #         mywindow.print();
    #         return true;
    #     });
    #         </script>
    #             |;
    #         }
        
    #     }
    }
}
# sub tool_step1 {
#     my ( $self, $args ) = @_;
#     my $cgi = $self->{'cgi'};
#     my $template = $self->get_template({ file => 'tool-step1.tt' });
#     my $dbh = C4::Context->dbh;

#     # find all borrowers
#     my $borrowers_query = "
#         SELECT borrowernumber FROM borrowers
#     ";
#     my $sth = $dbh->prepare($borrowers_query);
#     $sth->execute();
#     my @borrowers_list;
#     while ( my $row = $sth->fetchrow_array() ) {
#         push( @borrowers_list, $row );
#     }

#     # $template->param(words => \@borrowers_list);
#     # $self->output_html($template->output());
#     #check if a borrower has a suggestion
#     while (my $borrowernumber = each @borrowers_list){
#         # my ($borrowernumber, $firstname, $surname) = @borrow;
#         my $borrow_query = "SELECT * FROM suggestions  WHERE suggestedby LIKE $borrowernumber";
#         $sth = $dbh->prepare($borrow_query);
#         $sth->execute();
#         my @suggest_list;
#         while ( my $row = $sth->fetchrow_hashref() ) {
#             push( @suggest_list, $row );
#         }

#         if(@suggest_list){
#             #if list is not empty
#             $template->param(words => \@suggest_list,
#                             borrower => scalar Koha::Patrons->find($borrowernumber));
#             # print $template->output();
#             $self->output_html($template->output());
#             q|
#         <script>
#         var button = document.getElementById("pdfButton");
#       var makepdf = document.getElementById("generatePDF");
#       button.addEventListener("click", function () {
#          var mywindow = window.open("", "PRINT", "height=600,width=600");
#          mywindow.document.write(makepdf.innerHTML);
#          mywindow.document.close();
#          mywindow.focus();
#          mywindow.print();
#          return true;
#       });
#         </script>
#             |;
#         }
    
#     }
#     # # my $words = $dbh->selectcol_arrayref( "SELECT suggestedby FROM suggestions" );
#     # $template->param( words => \@results );
#     # # print $template->output();
#     # $self->output_html( $template->output() );

# }

# sub tool_step2 {
#     my ( $self, $args ) = @_;
#     my $cgi = $self->{'cgi'};
#     my $template = $self->get_template({ file => 'tool-step2.tt' });
#     my $dbh = C4::Context->dbh;

#     # find all borrowers who suggested
#     my $suggestors_query = "
#         SELECT borrowernumber FROM suggestions GROUP BY borrowernumber
#     ";
#     my $sth = $dbh->prepare($suggestors_query);
#     $sth->execute();
#     my @suggestors_id_list;
#     while ( my @row = $sth->fetchrow_array() ) {
#         push( @suggestors_id_list, @row );
#     }
    
#     my @suggestor_list;
#     while (my ($borrowernumber) = each @suggestors_id_list){
#         # my ($borrowernumber, $firstname, $surname) = @borrow;
#         push(@suggestor_list, scalar Koha::Patrons->find($borrowernumber));
#     }
#     $template->param( suggestor_list => \@suggestor_list);

#     $self->output_html($template->output());
# }

sub configure {
    my ( $self, $args ) = @_;

    my $cgi = $self->{'cgi'};
}

sub install() {
    my ( $self, $args ) = @_;

    return 1;
}

sub uninstall() {
    my ( $self, $args ) = @_;

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