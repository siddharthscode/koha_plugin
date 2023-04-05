package Koha::Plugin::indentation;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

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
}

sub tool {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    my $template = $self->get_template({ file => 'tool-step1.tt' });
    my $dbh = C4::Context->dbh;
    my $suggestions_table = $self->get_qualified_table_name('suggestions');

    # find all borrowers
    my $borrowers_query = "
        SELECT borrowernumber, firstname, surname FROM borrowers
    ";
    my $sth = $dbh->prepare($borrowers_query);
    $sth->execute();
    my @borrowers_list;
    while ( my @row = $sth->fetchrow_array() ) {
        push( @borrowers_list, @row );
    }

    # $template->param(words => \@borrowers_list);
    # $self->output_html($template->output());
    #check if a borrower has a suggestion
    while (my ($borrowernumber, $firstname, $surname) = each @borrowers_list){
        # my ($borrowernumber, $firstname, $surname) = @borrow;
        my $borrow_query = "SELECT * FROM suggestions  WHERE suggestedby LIKE $borrowernumber";
        $sth = $dbh->prepare($borrow_query);
        $sth->execute();
        my @suggest_list;
        while ( my $row = $sth->fetchrow_hashref() ) {
            push( @suggest_list, $row );
        }

        if(@suggest_list){
            #if list is not empty
            $template->param(words => \@suggest_list,
                            borrower => $firstname);
            # print $template->output();
            $self->output_html($template->output());
            q|
        <script>
        var button = document.getElementById("pdfButton");
      var makepdf = document.getElementById("generatePDF");
      button.addEventListener("click", function () {
         var mywindow = window.open("", "PRINT", "height=600,width=600");
         mywindow.document.write(makepdf.innerHTML);
         mywindow.document.close();
         mywindow.focus();
         mywindow.print();
         return true;
      });
      
        </script>
            |;
        }
    
    }






    # # my $words = $dbh->selectcol_arrayref( "SELECT suggestedby FROM suggestions" );
    # $template->param( words => \@results );
    # # print $template->output();
    # $self->output_html( $template->output() );

}

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