#!/usr/bin/perl

use strict;
use warnings;

# turn off output buffering
$| = 1;

package MyWidget;
use Data::Dumper;
use IO::Select;
use QtGui4;
use QtCore4;
use QtCore4::isa qw( Qt::Widget );
use QtCore4::slots handleInput => [];

our $square_size = 50;

sub NEW {
    my ( $class, $parent ) = @_;
    $class->SUPER::NEW($parent);
    this->{_x}       = 45;
    this->{_y}       = 45;
    this->{selector} = IO::Select->new();
    this->{selector}->add( \*STDIN );
    this->{chan1_samples} = [];
    this->{chan1_sum}     = 0;
    this->{chan2_samples} = [];
    this->{chan2_sum}     = 0;
}

sub sizeHint {
    return Qt::Size( 600, 600 );
}

sub paintEvent {
    my $painter = Qt::Painter(this);
    my $size    = this->size();
    my $width   = $square_size;
    my $height  = $square_size;
    my $x       = this->{_x};
    my $y       = this->{_y};
    $painter->fillRect( $x, $y, $width, $height, Qt::blue() );
    $painter->end();
}

sub scale {
    return 10000;
}

our $valid_row_regex = qr/
   (?<chan1>-?[0-9]+(?:\.[0-9]*)),\s*
   (?<chan2>-?[0-9]+(?:\.[0-9]*))
/x;

sub handleInput {
    if ( not this->{selector}->can_read(0.0) ) {
        return;
    }
    my $i = 0;
    while ( this->{selector}->can_read(0.0) ) {
        my $line = readline( \*STDIN );
        last if not $line;
        print $line, "\n";
        if ( $line =~ m/$valid_row_regex/ ) {
            my $chan_1 = $+{chan1};
            my $chan_2 = $+{chan2};

            push @{ this->{chan1_samples} }, $chan_1;
            this->{chan1_sum} += $chan_1;
            push @{ this->{chan2_samples} }, $chan_2;
            this->{chan2_sum} += $chan_2;

            my $samples = scalar @{ this->{chan1_samples} };

            if ( $samples > 1000 ) {
                my $drop = shift @{ this->{chan1_samples} };
                this->{chan1_sum} -= $drop;
                $drop = shift @{ this->{chan2_samples} };
                this->{chan2_sum} -= $drop;
            }
            my $chan1_avg = this->{chan1_sum} / $samples;
            my $chan2_avg = this->{chan2_sum} / $samples;

            # my $new_x = ( this->scale() * ( $chan_1 - $chan1_avg ) );
            # my $new_y = ( this->scale() * ( $chan_2 - $chan2_avg ) );
            # this->{_x} += $new_x;
            # this->{_y} += $new_y;
            my $chan1_scale = 1.1;
            my $chan2_scale = 1;
            my $chan_1_2_avg = (($chan1_avg * $chan1_scale +
                $chan2_avg * $chan2_scale) / 2.0) || 1;
            my $delta_x = ($chan_1 * $chan1_scale - $chan_2 * $chan2_scale) /
                $chan_1_2_avg * 1;
            my $x_deadzone = 0.5;
            if ($delta_x > $x_deadzone) {
                this->{_x} += $delta_x - $x_deadzone;
            }
            if ($delta_x < -$x_deadzone) {
                this->{_x} += $delta_x - -$x_deadzone;
            }
#            my $chan1_scaled = $chan_1 * this->scale();
#            my $chan2_scaled = $chan_2 * this->scale() * 1.2;
#            my $chan1_thresh = 0;
#            my $chan2_thresh = 0;
#            if ( $chan1_scaled > $chan1_thresh ) {
#                this->{_x} += $chan1_scaled - $chan1_thresh;
#            }
#            if ( $chan2_scaled > $chan2_thresh ) {
#                this->{_x} -= $chan2_scaled - $chan2_thresh;
#            }

            my $size = this->size();
            if ( this->{_x} < 0 ) {
                this->{_x} = 0;
            }
            elsif ( this->{_x} > $size->width() - $square_size ) {
                this->{_x} = $size->width() - $square_size;
            }
            if ( this->{_y} < 0 ) {
                this->{_y} = 0;
            }
            elsif ( this->{_y} > $size->height() - $square_size ) {
                this->{_y} = $size->height() - $square_size;
            }
        }
        if ( $i % 10 == 0 ) {
            this->update();
        }
    }
    this->update();
}

package main;

use QtCore4;
use QtGui4;

my $app = Qt::Application( \@ARGV );

my $widget = MyWidget->new();
$widget->show();

my $timer = Qt::Timer($widget);
$widget->connect( $timer, SIGNAL 'timeout()', $widget, SLOT 'handleInput()' );
$timer->start(10);

exit $app->exec();
