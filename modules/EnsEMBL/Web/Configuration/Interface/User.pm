package EnsEMBL::Web::Configuration::Interface::User;

### Sub-class to do user-specific interface functions

use strict;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration::Interface );

sub add {
  ### Creates a panel containing an empty record form
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'add', 'Add a New Record')) {
    $panel->add_components(qw(add     EnsEMBL::Web::Component::Interface::User::add));
    $self->add_form($panel, qw(add    EnsEMBL::Web::Component::Interface::User::add_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Register");
  }
  return undef;
}

sub check_input {
  ## checks user input for duplicate emails
  my ($self, $object, $interface) = @_;
  if ($object->param('email')) {
    my $existing_user = EnsEMBL::Web::Data::User->find(email => $object->param('email'));
    if ($existing_user) {
      if (my $panel = $self->interface_panel($interface, 'add', 'Register')) {
        $panel->add_components(qw(duplicate   EnsEMBL::Web::Component::Interface::User::duplicate));
        $self->{page}->content->add_panel($panel);
        $self->{page}->set_title("Registration Error");
      }
      return undef;
    } else {
      my $url = '/common/user/register?dataview=preview;db_action='.$object->param('db_action').';name='.$object->param('name').';email='.$object->param('email').';organisation='.$object->param('organisation');
      return $url;
    }
  }
}

sub save {
  my ($self, $object, $interface) = @_;

  my $script = $interface->script_name || $object->script;
  $interface->cgi_populate($object);
  
  if ($ENV{'ENSEMBL_USER_ID'}) {
    $interface->data->modified_by($ENV{'ENSEMBL_USER_ID'});
  } else {
    $interface->data->salt(EnsEMBL::Web::Tools::RandomString::random_string(8));
    $interface->data->status('pending');
    $interface->data->created_by($interface->data->id);
  }

  my $url;
  if ($interface->data->save) {
    ## redirect to confirmation page 
    $url = "/common/$script?dataview=success;email=" . $object->param('email');
    $url .= ';record_id='.$object->param('record_id') if $object->param('record_id');
  } else {
    $url = "/common/$script?dataview=failure";
  }
  
  return $url;
}

1;
