package Math::LinearCombination;

require 5.005_62;
use strict;
use warnings;
use Carp;
our ($VERSION);
$VERSION = '0.02';
use fields (
   '_entries', # hash sorted on variable id's, with a ref to hash for
	       # each variable-coefficient pair:
	       #  { var => $var_object, coeff => $num_coefficient }
);

use overload
    '+'    => 'add',
    '-'    => 'subtract',
    '*'    => 'mult',
    '/'    => 'div',
    "\"\"" => 'stringify';

### Object builders
sub new {
    # parse the arguments
    my $proto = shift;
    my $pkg = ref($proto) || $proto;
    if(@_ == 1 
       && defined(ref $_[0]) 
       && $_[0]->isa('Math::LinearCombination')) {
	# new() has been invoked as a copy ctor
	return $_[0]->clone();
    }
    elsif(@_) {
	croak "Invalid nr. of arguments passed to new()";
    }

    # construct the object
    my Math::LinearCombination $this = fields::new($pkg);

    # apply default values
    $this->{_entries} = {};

    $this;
}

sub make { 
    # alternative constructor, which accepts a sequence (var1, coeff1, var2, coeff2, ...)
    # as an initializer list
    my $proto = shift;
    my $pkg = ref($proto) || $proto;
    my $ra_args = \@_;
    if(defined($ra_args->[0]) 
       && defined(ref $ra_args->[0]) 
       && ref($ra_args->[0]) eq 'ARRAY') {
	$ra_args = $ra_args->[0]; # argument array was passed as a ref
    };
    my $this = new $pkg;
    while(@$ra_args) {
	my $var = shift @$ra_args;
	defined(my $coeff = shift @$ra_args) or die "Odd number of arguments";
	$this->add_entry(var => $var, coeff => $coeff);
    }
    return $this;
}

sub clone {
    my Math::LinearCombination $this = shift;
    my Math::LinearCombination $clone = $this->new();
    $clone->add_inplace($this);
    return $clone;
}

sub add_entry {
    my Math::LinearCombination $this = shift;
    my %arg = (@_ == 1 && defined(ref $_[0]) && ref($_[0]) eq 'HASH')
	? %{$_[0]} : @_;

    exists $arg{var} or croak "No `var' argument given to add_entry()";
    my $var = $arg{var};
    UNIVERSAL::can($var,'id') or croak "Given `var' argument has no id() method";
    UNIVERSAL::can($var,'name') or croak "Given `var' argument has no name() method";
    UNIVERSAL::can($var,'evaluate') or croak "Given `var' argument has no evaluate() method";

    exists $arg{coeff} or croak "No `coeff' argument given to add_entry()";
    my $coeff = $arg{coeff};

    my $entry = $this->{_entries}->{$var->id()} ||= {};
    if(exists $entry->{var}) { # we're adding to an existing entry
	$entry->{var} == $var or 
	    croak "add_entry() found distinct variable with same id";
    }
    else { # we're initializing a new entry
	$entry->{var} = $var;
    }
    $entry->{coeff} += $coeff;

    return;
}

### Accessors
sub get_entries {
    my Math::LinearCombination $this = shift;
    return $this->{_entries};
}

sub get_variables {
    my Math::LinearCombination $this = shift;
    my @vars = map { $this->{_entries}->{$_}->{var} } sort keys %{$this->{_entries}};
    return wantarray ? @vars : \@vars;
}

sub get_coefficients {
    my Math::LinearCombination $this = shift;
    my @coeffs = map { $this->{_entries}->{$_}->{coeff} } sort keys %{$this->{_entries}};
    return wantarray ? @coeffs : \@coeffs;
}

### Mathematical manipulations
sub add_inplace {
    my Math::LinearCombination $this = shift;
    my Math::LinearCombination $arg  = shift;
    while(my($id,$entry) = each %{$arg->{_entries}}) {
	$this->add_entry($entry);
    }
    $this->remove_zeroes();
    return $this;
}

sub add {
    my ($a,$b) = @_;
    my $sum = $a->clone();
    $sum->add_inplace($b);
    return $sum;
}

sub subtract {
    my ($a,$b,$flip) = @_;
    my $diff = $flip ? $a->clone() : $b->clone(); # the negative term ...
    $diff->negate_inplace(); # ... is negated
    $diff->add_inplace($flip ? $b : $a); # and the positive term is added
    return $diff;
}

sub negate_inplace {
    my Math::LinearCombination $this = shift;
    $this->multiply_with_constant_inplace(-1.0);
    return $this;
}

sub multiply_with_constant_inplace {
    my Math::LinearCombination $this = shift;
    my $constant = shift;
    while(my($id,$entry) = each %{$this->{_entries}}) {
	$entry->{coeff} *= $constant;
    }
    $this->remove_zeroes();
    return $this;
}

sub mult {
    my ($a,$b) = @_;
    my $prod = $a->clone(); # clones the linear combination
    $prod->multiply_with_constant_inplace($b); # multiplies with the scalar
    return $prod;
}

sub div {
    my ($a,$b,$flip) = @_; 
    die "Unable to divide a scalar (or anything else) by a " . ref($a) . ". Stopped"
	if $flip;
    return $a->mult(1.0/$b);
}

sub evaluate { 
    my Math::LinearCombination $this = shift;
    my $val = 0.0;
    while(my($id,$entry) = each %{$this->{_entries}}) {
	$val += $entry->{var}->evaluate() * $entry->{coeff};
    }
    return $val;
}

sub remove_zeroes {
    my Math::LinearCombination $this = shift;
    my @void_ids = grep { $this->{_entries}->{$_}->{coeff} == 0.0 } keys %{$this->{_entries}};
    delete $this->{_entries}->{$_} foreach @void_ids;
    return;
}

### I/O
sub stringify {
    my Math::LinearCombination $this = shift;

    my @str_entries;
    foreach my $key (sort keys %{$this->{_entries}}) {
	my $var   = $this->{_entries}->{$key}->{var};
	my $coeff = $this->{_entries}->{$key}->{coeff};
	my $str_entry = '';
	if($coeff < 0.0 || @str_entries) { # adds the sign only if needed
	    $str_entry .= $coeff > 0.0 ? '+' : '-';
	}
	if(abs($coeff) != 1.0) { # adds the coefficient value if not +1 or -1
	    $str_entry .= sprintf("%g ", abs($coeff));
	}
	$str_entry .= $var->name();
	push @str_entries, $str_entry;
    }

    return @str_entries ? join(' ', @str_entries) : '0.0';
}

1;

__END__

=head1 NAME

Math::LinearCombination - sum of variables with a numerical coefficient

=head1 SYNOPSIS

  use Math::LinearCombination;
  use Math::SimpleVariable; # for the variable objects

  # build a linear combination
  my $x1 = new Math::SimpleVariable(name => 'x1');
  my $x2 = new Math::SimpleVariable(name => 'x2');
  my $lc = new Math::LinearCombination();
  $lc->add_entry(var => $x1, coeff => 3.0);
  $lc->add_entry(var => $x2, coeff => 1.7);
  $lc->add_entry(var => $x2, coeff => 0.3); # so x2 has a coefficient of 2.0
  print $lc->stringify(), "\n";

  # do some manipulations
  $lc->negate_inplace(); # reverts the coefficient signs
  $lc->multiply_with_constant_inplace(2.0); # doubles all coefficients
 
  # evaluate the linear combination
  $x1->{value} = 3;
  $x2->{value} = -1;
  print $lc->evaluate(), "\n"; # prints -14

=head1 DESCRIPTION

Math::LinearCombination is a module for representing mathematical
linear combinations of variables, i.e. expressions of the format

  a1 * x1 + a2 * x2 + ... + an * xn

with x1, x2, ..., xn variables, and a1, a2, ..., an numerical coefficients.
Evaluation and manipulation of linear combinations is also supported.

... STILL TO BE FINISHED

=head1 SEE ALSO

perl(1).

=head1 VERSION

This is version $Revision: 1.10 $ of Math::LinearCombination,
last edited at $Date: 2001/07/18 12:50:50 $.

=head1 AUTHOR

Wim Verhaegen E<lt>wimv@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright (C) 2001 Wim Verhaegen. All rights reserved.
This program is free software; you may redistribute
and/or modify it under the same terms as Perl itself.

=cut
