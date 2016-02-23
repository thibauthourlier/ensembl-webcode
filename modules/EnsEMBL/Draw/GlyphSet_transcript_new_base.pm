=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet_transcript_new_base;

use strict;

use List::Util qw(min max);
use List::MoreUtils qw(natatime);

use base qw(EnsEMBL::Draw::GlyphSet);

# In "collapsed" style, a single bead-string is drawn. This is fat
# wherever any consituent transcript has an exon at that position.
# It is used by render_collapsed and render_alignslice_collapsed.
# It is accessed via draw_collapsed_genes.
#
# In "expanded" style, each transcript is simply drawn separately,
# with full exon structure and labels for each. It is used by
# render_transcripts and render_alignslice_transcripts. It is accessed
# via draw_expanded_transcripts.
#
# In "rect" style, the region occupied by a gene is simply drawn as a
# rectangle. It is used in render_genes. It is accessed via
# draw_rect_genes.

# The data to be passed in must be in the form of an array of hashes
# representing a set of genes or, in expanded style, transcripts. Whether
# genes or transcripts are the objects represented, they must contain the
# following keys.
#
#   colour_key =>  key of main colour to use for object
#   start, end =>  complete extent of object in bp. Need not be truncated
#                  to edge of screen: we'll do that.
#   strand =>      the strand it lies on
#   title, href => for the respective composites, if applicable
#   label =>       text of label
#   highlight =>   a colour in which to highlight object, if needed
#   joins => [{    join lines used to join homologous genes, etc
#     colour => colour of join
#     key =>    tag key
#     legend => text for legend
#   }]
#   exons => [{    draw internal exons
#     start,end =>               locations of exon
#     strand =>                  strand of exon (needed for alignslice)
#     coding_start,coding_end => internal offset to coding part of exon
#   }]

##########################################################
# UTILITIES USED IN ALL STYLES                           #
##########################################################

# joining genes (compara views)

sub _draw_join {
  my ($self,$target,$j) = @_;
  
  $self->join_tag($target,$j->{'key'},0.5,0.5,$j->{'colour'},'line',1000);
  $self->{'legend'}{'gene_legend'}{'joins'}{'priority'} ||= 1000;
  if($j->{'legend'}) {
    $self->{'legend'}{'gene_legend'}{'joins'}{'legend'}{$j->{'legend'}} =
      $j->{'colour'};
  }
}

# legends 

sub _use_legend {
  my ($self,$used_colours,$colour_key) = @_;

  my $colour = 'orange';
  my $label = 'Other';
  my $section = 'none';
  if($colour_key) {
    $colour     = $self->my_colour($colour_key);
    if($colour) {
      $label      = $self->my_colour($colour_key, 'text');
      $section    = $self->my_colour($colour_key,'section') || 'none';
    }
  }
  my $section_name = $self->my_colour("section_$section",'text') ||
                      $self->my_colour("section_none",'text');
  my $section_prio = $self->my_colour("section_$section",'prio') ||
                      $self->my_colour("section_none",'prio');
  if($section) {
    $section = {
      key => $section,
      name => $section_name,
      priority => $section_prio,
    };
  }
  $used_colours->{$label} = [$colour,$section];
}

sub _make_legend {
  my ($self,$objs,$type) = @_;

  my %used_colours;
  $self->_use_legend(\%used_colours,$_->{'colour_key'}) for(@$objs);
  my %legend_old = @{$self->{'legend'}{'gene_legend'}{$type}{'legend'}||[]};
  $used_colours{$_} = $legend_old{$_} for keys %legend_old;
  my @legend = %used_colours;
  $self->{'legend'}{'gene_legend'}{$type} = {
    priority => $self->_pos,
    legend   => \@legend
  };
}

# labels

sub text_details {
  my $self = shift;
  
  if (!$self->{'text_details'}) {
    my %font_details = $self->get_font_details('outertext', 1);
    $self->{'text_details'} = { %font_details, height => [ $self->get_text_width(0, 'Xg', 'Xg', %font_details) ]->[3] + 1 };
  }
  
  return $self->{'text_details'};
}

sub _add_label {
  my ($self,$composite,$g) = @_;

  return unless $g->{'label'};
  
  my $text_details = $self->text_details;
  my $y            = $composite->height;
  my $yo = $y;

  foreach my $line (split("\n",$g->{'label'})) {
    $composite->push($self->Text({
      x         => $g->{'_bstart'},
      y         => $y,
      halign    => 'left',
      colour    => $self->my_colour($g->{'colour_key'}),
      text      => $line,
      absolutey => 1,
      %$text_details
    }));
    $y += $text_details->{'height'};
  }
 
  return $y-$yo;
}


#############################################################
# USED IN "COLLAPSED" STYLE                                 #
#############################################################

sub _draw_collapsed_gene_base {
  my ($self,$composite2,$length,$gene) = @_;    

  my $start = max($gene->{'start'},1);
  my $end   = min($gene->{'end'},$length);
  
  $composite2->push($self->Rect({
    x         => $start, 
    y         => 4,
    width     => $end - $start + 1,
    height    => 0.4, 
    colour    => $self->my_colour($gene->{'colour_key'}), 
    absolutey => 1
  }));
}

sub _draw_collapsed_exon {
  my ($self,$composite2,$length,$gene,$exon) = @_;

  my $s = max($exon->{'start'},1);
  my $e = min($exon->{'end'},$length);
  
  $composite2->push($self->Rect({
    x         => $s - 1,
    y         => 0,
    width     => $e - $s + 1,
    height    => 8,
    colour    => $self->my_colour($gene->{'colour_key'}),
    absolutey => 1
  }));
}

sub draw_collapsed_genes {
  my ($self,$length,$labels,$strand,$genes) = @_;

  my $strand_flag      = $self->my_config('strand');
  return unless @$genes;
  my %used_colours;
  foreach my $g (@$genes) {
    next if $strand != $g->{'strand'} and $strand_flag eq 'b';
    my $composite = $self->Composite({
      y      => 0,
      height => 8,
      title  => $g->{'title'},
      href   => $g->{'href'},
    });
      
    $self->_draw_collapsed_gene_base($composite,$length,$g);
    foreach my $e (@{$g->{'exons'}}) {
      $self->_draw_collapsed_exon($composite,$length,$g,$e);
    }
    foreach my $j (@{$g->{'joins'}||[]}) {
      $self->_draw_join($composite,$j);
    }
  
    # shift the composite container by however much we're bumped
    my $bump_height  = 10;
    $bump_height += $self->_add_label($composite,$g) if $labels;

    # bump
    $composite->y($composite->y - $strand * $bump_height * $g->{'_bump'});
    $composite->colour($g->{'highlight'}) if $g->{'highlight'};
    $self->push($composite);
  }
  $self->_make_legend($genes,$self->my_config('name'));
}

#########################################################
# USED IN EXPANDED STYLE                                #
#########################################################

sub _draw_expanded_exon {
  my ($self,$composite2,$t,$h,$e,$length) = @_;
 
  return unless $e->{'start'} or $e->{'end'}; 
  my $non_coding_height = ($self->my_config('non_coding_scale')||0.75) * $h;
  my $non_coding_start  = ($h - $non_coding_height) / 2;
  my $colour    = $self->my_colour($t->{'colour_key'});
  my $box_start = max($e->{'start'}, 1);
  my $box_end   = min($e->{'end'}, $length);
  if($e->{'start'}==0) {
    $composite2->push($self->Line({
      x         => $box_start - 1,
      y         => int($h/2),
      width     => $box_end-$box_start + 1,
      height    => 0,
      absolutey => 1,
      colour    => 'green',
      dotted    => 1
    }));
  } else {
    $composite2->push($self->Rect({
      x            => $box_start - 1 ,
      y            => $non_coding_start,
      width        => $box_end - $box_start + 1,
      height       => $non_coding_height,
      bordercolour => $colour,
      absolutey    => 1,
    }));
    if(exists $e->{'coding_start'}) {
      my $fill_start = max($e->{'start'} + $e->{'coding_start'}, 1);
      my $fill_end   = min($e->{'end'}   - $e->{'coding_end'}, $length);
      
      if ($fill_end >= $fill_start) {
        $composite2->push($self->Rect({
          x         => $fill_start - 1,
          y         => 0,
          width     => $fill_end - $fill_start + 1,
          height    => $h,
          colour    => $colour,
          absolutey => 1,
        }));
      }
    }
  }
}

sub _draw_introns {
  my ($self,$composite2,$t,$h,$length,$strand) = @_;

  my $colour = $self->my_colour($t->{'colour_key'});
  my ($exon_stageleft,$exon_stageright) = (0,0);
  my @introns;
  foreach my $e (@{$t->{'exons'}}) {
    next unless $e->{'start'} or $e->{'end'}; 
    if($e->{'start'} > $length) { $exon_stageright = 1; }
    elsif($e->{'end'} <= 0) { $exon_stageleft = 1; }
    else { push @introns,$e; }
  }
  # add off-screen endpoints, duplicate, pair up
  unshift @introns,{end => 0,dotted => 1} if $exon_stageleft;
  push @introns,{start => $length, dotted => 1} if $exon_stageright;
  @introns = map { ($_,$_) } @introns;
  my $in_it = natatime(2,@introns[1..$#introns-1]);
  while(my @pair = $in_it->()) {
    my $intron_start = max($pair[0]->{'end'}+1,0);
    my $intron_end = min($pair[1]->{'start'}-1,$length);
    my $dotted = ($pair[0]->{'dotted'} || $pair[1]->{'dotted'});
    if($dotted) {
      $composite2->push($self->Line({
        x         => $intron_start - 1,
        y         => int($h/2),
        width     => $intron_end - $intron_start + 1,
        height    => 0,
        colour    => $colour,
        absolutey => 1,
        strand    => $strand,
        dotted => 1,
      }));
    } else {
      $composite2->push($self->Intron({
        x         => $intron_start - 1,
        y         => 0,
        width     => $intron_end - $intron_start + 1,
        height    => $h,
        colour    => $colour,
        absolutey => 1,
        strand    => $strand,
      }));
    }
  }
}

sub _draw_expanded_transcript {
  my ($self,$composite2,$t,$h,$length,$strand) = @_;

  foreach my $j (@{$t->{'joins'}||[]}) {
    $self->_draw_join($composite2,$j);
  }
  foreach my $e (@{$t->{'exons'}||[]}) {
    next if $e->{'start'} > $length or $e->{'end'} <= 0;
    $self->_draw_expanded_exon($composite2,$t,$h,$e,$length);
  }
  $self->_draw_introns($composite2,$t,$h,$length,$strand);
}

# Probably not used anywhere any more?
sub _draw_grey_arrow {
  my ($self,$strand,$length,$h,$colour) = @_;

  my $pix_per_bp = $self->scalex;
  my ($ay,$ao,$am); 
  if ($strand) {
    ($ay,$ao,$am) = (-4,$length,-1);
  } else {
    ($ay,$ao,$am) = ($h+4,0,1);
  }
  $self->push($self->Line({
    x         => 0,
    y         => $ay,
    width     => $length,
    height    => 0,
    absolutey => 1,
    colour    => $colour
  }));
  $self->push($self->Poly({
    absolutey => 1,
    colour    => $colour,
    points    => [ 
      $ao+$am*4/$pix_per_bp, $ay-2*$am,
      $ao, $ay,
      $ao+$am*4/$pix_per_bp, $ay+2*$am,
    ]
  }));
}

sub draw_expanded_transcripts {
  my ($self,$length,$draw_labels,$strand,$tdraw) = @_;

  return unless @$tdraw;
  my $target = $self->get_parameter('single_Transcript');
  my $h = $self->my_config('height') || ($target ? 30 : 8);
  my $strand_flag = $self->my_config('strand');
  foreach my $td (@$tdraw) { 
    next if $strand != $td->{'strand'} and $strand_flag eq 'b';
    next if $td->{'start'} > $length or $td->{'end'} < 1;
    my $composite = $self->Composite({
      y      => 0,
      height => $h,
      title  => $td->{'title'},
      href   => $td->{'href'},
      class  => 'group',
    });

    $self->_draw_expanded_transcript($composite,$td,$h,$length,$strand);
    
    my $bump_height  = 1.6 * $h;
    $bump_height += $self->_add_label($composite,$td) if $draw_labels;
    $composite->y($composite->y - $strand * $bump_height * $td->{'_bump'});

    $composite->colour($td->{'highlight'}) if $td->{'highlight'};
    if ($target) {
      # check the strand of one of the transcript's exons
      my $estrand = ((($td->{'exons'}||[])->[0])||{})->{'strand'};
      my $colour = $self->my_colour($td->{'colour_key'});
      $self->_draw_grey_arrow($estrand,$length,$h,$colour);
    }
    $self->push($composite);
  }
  $self->_make_legend($tdraw,$self->type);
}

########################################################
# USED IN "rect" STYLE                                 #
########################################################
    
sub _draw_rect_gene {
  my ($self,$g,$length) = @_;

  my $pix_per_bp = $self->scalex;

  my $start = max($g->{'start'},1);
  my $end = min($g->{'end'},$length);

  my $rect = $self->Rect({
    x => $start-1,
    y => 0,
    width => $end-$start+1,
    height => 4,
    colour => $self->my_colour($g->{'colour_key'}),
    absolutey => 1,
    href => $g->{'href'},
    title => $g->{'title'},
  });
  $self->push($rect);
  if($g->{'highlight'}) {
    $self->unshift($self->Rect({
      x         => ($start-1) - 1/$pix_per_bp,
      y         => -1,
      width     => ($end-$start+1) + 2/$pix_per_bp,
      height    => 6,
      colour    => $g->{'highlight'},
      absolutey => 1
    }));
  }
  $self->_draw_join($rect,$_) for(@{$g->{'joins'}||[]});
  return $rect;
}

sub _draw_bookend {
  my ($self,$composite,$g) = @_;

  my $pix_per_bp = $self->scalex;
  $composite->push(
    $self->Rect({
      x         => $g->{'_bstart'}+8,
      y         => 4,
      width     => 0,
      height    => 4,
      colour    => $self->my_colour($g->{'colour_key'}),
      absolutey => 1
    }),
    $self->Rect({
      x         => $g->{'_bstart'}+8,
      y         => 8,
      width     => 3/$pix_per_bp,
      height    => 0,
      colour    => $self->my_colour($g->{'colour_key'}),
      absolutey => 1
    })
  );
}

sub draw_rect_genes {
  my ($self,$ggdraw,$length,$draw_labels,$strand) = @_;

  my $strand_flag = $self->my_config('strand');
  my $pix_per_bp = $self->scalex;
  my $rects_rows = $self->mr_bump($ggdraw,0,$length);
  foreach my $g (@$ggdraw) {
    next if $strand != $g->{'strand'} and $strand_flag eq 'b';
    my $rect = $self->_draw_rect_gene($g,$length);
    $rect->y($rect->y + (6*$g->{'_bump'}));
  } 
  if($draw_labels) {
    $_->{'_lwidth'} += 8/$pix_per_bp for(@$ggdraw);
    $self->mr_bump($ggdraw,2,$length); # Try again

    foreach my $g (@$ggdraw) {
      next if $strand != $g->{'strand'} and $strand_flag eq 'b';
      my $composite = $self->Composite({
        y => 0,
        x => $g->{'_bstart'},
        width => $g->{'_lwidth'},
        absolutey => 1,
        colour => $g->{'highlight'},
      });
      $self->_add_label($composite,$g);
      $composite->x($composite->x+8/$pix_per_bp);
      $self->_draw_bookend($composite,$g);
      $composite->y($g->{'_lheight'}*$g->{'_bump'}+($rects_rows*6));
      $self->push($composite);
    }
  }
  $self->_make_legend($ggdraw,$self->type);
}

1;
