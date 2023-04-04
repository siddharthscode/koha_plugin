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

    my $query = "
        SELECT * FROM suggestions
    ";

    my $sth = $dbh->prepare($query);
    $sth->execute();
    my @results;
    while ( my $row = $sth->fetchrow_hashref() ) {
        push( @results, $row );
    }




    # my $words = $dbh->selectcol_arrayref( "SELECT suggestedby FROM suggestions" );
    $template->param( words => \@results );
    # print $template->output();
    $self->output_html( $template->output() );

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