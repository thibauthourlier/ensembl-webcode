package EnsEMBL::Web::DOM::Node::Element::Style;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'style';
}

1;