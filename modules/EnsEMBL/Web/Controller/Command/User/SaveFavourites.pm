package EnsEMBL::Web::Controller::Command::User::SaveFavourites;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::Record::User::SpeciesList;
use EnsEMBL::Web::Document::HTML::SpeciesList;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Ajax');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::DataUser');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
  print "Content-type:text/html\n\n";
  my $user = $self->filters->user($ENSEMBL_WEB_REGISTRY->get_user->id);

  my ($species_list) = $user->specieslists;
  $species_list = EnsEMBL::Web::Data::Record::User::SpeciesList->new
    unless $species_list;
    
  $species_list->favourites($self->get_action->get_named_parameter('favourites'));
  $species_list->list($self->get_action->get_named_parameter('list'));
  $species_list->user_id($user->id);
  $species_list->save;

  print EnsEMBL::Web::Document::HTML::SpeciesList->render("fragment");

}

}

1;
