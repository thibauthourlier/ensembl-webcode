package EnsEMBL::Web::DOM::Node::Element::Html;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'html';
}

1;