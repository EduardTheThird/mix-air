#!/usr/bin/ruby

# Simple SVG model generator for MW compatible FCs
# (c) 2015 Jonathan Hudson
# Licence MIT or GPL v2 or later (as you wish)

require 'cairo'
require 'stringio'
include Math

TFLAT=true  # Whether to make Tri / V-tails flat or veed
YFLAT=false # Whether to make Y{4,6} flat or veed

# Calculate motor coordinates for non-trivial platforms
class ShapeFarm
  RAD=0.017453292
  def generate xp,yp,radius,ns=6,offset=0
    p=[]
    0.upto(ns-1) do |n|
      ang = n*360.0/ns + offset
      ang %= 360
      x = radius*sin(RAD*ang)
      y = radius*cos(RAD*ang)
      p << [xp+x, yp-y] # y axis inverted for cairo coord set
    end
    p
  end
end

# The SVG generator
class Model
  attr_accessor :lw, :radius

  RAD = 0.017453292
  RADIUS=28

  # Motor direction for arrow indicators
  CW=0
  CCW=1
  NOARROW=-1

  # Position on the motor circle for arrow indicators
  NE=0
  SE=1
  SW=2
  NW=3

  # Colours
  BODY_GREY='#bababa'
  CIRCLE_GREEN = '#4CB944'
  ARROW_RED = '#fa0700'

  # We use StringIO in order to be able to add a (non-)copyright statement
  def initialize filename
    @lw = RADIUS
    @radius = RADIUS
    @name = filename
    @output = StringIO.new
    @surface = Cairo::SVGSurface.new(@output, 200,200)
    @cr = Cairo::Context.new(@surface)
  end

  # Draw an arbitrary path, x,y pairs terminated by !
  def draw_path path,fill=BODY_GREY,round=false
    @cr.set_line_cap(Cairo::LINE_JOIN_ROUND) if round
    @cr.set_source_color(fill)
    @cr.set_line_width(@lw)
    first = true
    path.each do |p|
      if p == '!'
	@cr.close_path
	first = true
      elsif first
	@cr.move_to(*p)
	first = false
      else
	@cr.line_to(*p)
      end
    end
    @cr.fill
    @cr.stroke
  end

  # Draw body parts, really just a rounded line
  def draw_body x1,y1,x2,y2
    @cr.set_source_color(BODY_GREY)
    @cr.set_line_width(@lw)
    @cr.set_line_join(Cairo::LINE_JOIN_ROUND)
    @cr.move_to(x1,y1)
    @cr.line_to(x2,y2)
  end

  # Draw a servo box (in rcolor), and black text
  def draw_servo x,y,label,rcolor=:black
    @cr.set_source_color(rcolor)
    @cr.rectangle(x, y, 28, 28);
    @cr.set_font_size(16)
    @cr.stroke
    @cr.move_to(x+4,y+20)
    @cr.set_source_color(:black)
    @cr.show_text(label);
    @cr.stroke
  end

  # Draw direction arrow at Y offset
  def draw_dirn y=80
    @cr.set_line_join(Cairo::LINE_JOIN_BEVEL)
    @cr.set_source_color(ARROW_RED)
    @cr.move_to(100,y)
    @cr.set_line_width(12)
    @cr.rel_line_to(0, 40)
    @cr.stroke
    @cr.set_line_width(1)
    @cr.move_to(100,y-5)
    @cr.rel_line_to(-15, 15)
    @cr.rel_line_to(30, 0)
    @cr.rel_line_to(-15, -15)
    @cr.fill
    @cr.stroke
  end

  # Draw a circle, perhaps with directional arrows
  # lyoffset, lxoffset change label position
  def draw_circle x,y,label,dirn=CCW,loc=NE,fill=nil,colour=nil,lyoffset=0,lxoffset=0
    col = (colour||CIRCLE_GREEN)
    @cr.set_font_size(@radius)
    @cr.set_line_join(Cairo::LINE_JOIN_MITER)
    @cr.set_line_width(3)

    if fill
      @cr.set_source_color(fill)
      @cr.circle(x,y, @radius)
      @cr.fill
      @cr.stroke
    end

    @cr.set_source_color(col)
    @cr.circle(x,y, @radius)

    if dirn != NOARROW
      arrow = @radius*0.6
      adelta = arrow*0.12
      x0 = x
      y0 = y
      dx = 0
      dy = 0
      radj = @radius / Math.sqrt(2)
      xadj = yadj = 0

      case loc
      when NE
	x0 += radj
	y0 -= radj
	case dirn
	when CW
	  xadj = yadj = -arrow
	  dy = adelta
	when CCW
	  xadj = yadj = arrow
	  dx = -adelta
	end
      when SE
	x0 += radj
	y0 += radj
	case dirn
	when CW
	  xadj = arrow
	  yadj = -arrow
	  dx = -adelta
	when CCW
	  xadj = -arrow
	  yadj = arrow
	  dy = -adelta
	end
      when SW
	x0 -= radj
	y0 += radj
	case dirn
      when CW
	  xadj = yadj = arrow
	  dy = -adelta
	when CCW
	  xadj = yadj = -arrow
	  dx = adelta
	end
      when NW
	x0 -= radj
	y0 -= radj
	case dirn
	when CW
	  xadj = -arrow
	  yadj = arrow
	  dx = adelta
	when CCW
	  xadj = arrow
	  yadj = -arrow
	  dy = adelta
	end
      end
      @cr.move_to(x0,y0)
      @cr.rel_line_to(dx, yadj)
      @cr.move_to(x0,y0)
      @cr.rel_line_to(xadj, dy)
    end
    @cr.stroke
    @cr.move_to(x-@radius/4+lxoffset,y+@radius/4+lyoffset)
    @cr.set_source_color(:black)
    @cr.show_text(label);
    @cr.stroke
  end

  # Reset line styles
  def end_body
    @cr.set_line_cap Cairo::LINE_CAP_ROUND
    @cr.stroke
    @cr.set_line_cap Cairo::LINE_CAP_BUTT
  end

  # close a model, write out with attribution
  def close
    @cr.show_page
    @surface.finish
    @output.rewind
    cc=false
    File.open(@name, "w") do |f|
      @output.each do |l|#
	f.puts(l)
	unless cc
	  f.puts("<!-- Public domain (CC-BY-SA if you or your laws insist), generated by Jonathan Hudson's svg_model_motors.rb -->")
	  cc = true
	end
      end
    end
  end
end


def render_bi
  m = Model.new "bicopter.svg"
  m.draw_body 40,100,160,100
  m.end_body
  m.draw_circle 40,100,"1",Model::CW,Model::NW
  m.draw_circle 160,100,"2",Model::CCW,Model::NE
  m.draw_servo  64, 120, "S1"
  m.draw_servo  108, 120, "S2"
  m.draw_dirn 70
  m.close
end

def render_tri
  m = Model.new "tri.svg"
  if TFLAT
    m.draw_body 40,40,160,40
    m.draw_body 100,40,100,160
  else
    m.draw_body 100,50,40,40
    m.draw_body 100,50,160,40
    m.draw_body 100,50,100,160
  end
  m.end_body
  m.draw_circle 100,160,"1",Model::CCW,Model::NW
  m.draw_circle 160,40,"2",Model::CCW,Model::NW
  m.draw_circle 40,40,"3", Model::CCW, Model::NE
  m.draw_servo  140, 140, "S1"
  m.draw_dirn 70
  m.close
end

def render_y4
  m = Model.new "y4.svg"
  m.draw_circle 100,170,"3",Model::CCW,Model::SE,false,:dark_green,14
  if YFLAT == true
    m.draw_body 40,40,160,40
    m.draw_body 100,40,100,140
  else
    m.draw_body 100,50,40,40
    m.draw_body 100,50,160,40
    m.draw_body 100,50,100,140
  end
  m.end_body
  m.draw_circle 160,40,"2",Model::CCW,Model::NE
  m.draw_circle 40,40,"4", Model::CW, Model::NW
  m.draw_circle 100,140,"1",Model::CW,Model::NE,"#fff8",nil,-10

  m.draw_dirn 60
  m.close
end

def render_y6
  m = Model.new "y6.svg"
  m.draw_circle 100,170,"4",Model::CW,Model::SW,false,:dark_green,14
  m.draw_circle 30,30,"6",Model::CCW,Model::NE,false,:dark_green,-10
  m.draw_circle 170,30,"5",Model::CCW,Model::NW,false,:dark_green,-10
  if YFLAT == true
    m.draw_body 40,50,160,50
    m.draw_body 100,50,100,140
  else
    m.draw_body 100,60,40,50
    m.draw_body 100,60,160,50
    m.draw_body 100,60,100,140
  end
  m.end_body
  m.draw_circle 145,55,"2",Model::CW,Model::NW,"#fff8",nil,12
  m.draw_circle 55,55,"3", Model::CW, Model::NE,"#fff8",nil,12
  m.draw_circle 100,140,"1",Model::CCW,Model::NW,"#fff8",nil,-10
  m.draw_dirn 60
  m.close
end

def render_vtail
  m = Model.new  "vtail_quad.svg"
  if TFLAT == true
    m.draw_body 40,40,160,40
    m.draw_body 100,40,100,180
  else
    m.draw_body 100,50,40,40
    m.draw_body 100,50,160,40
    m.draw_body 100,50,100,180
  end
  m.draw_body 100,180,140,160
  m.draw_body 100,180,60,160
  m.end_body
  m.draw_circle 140,160,"1",Model::CCW,Model::SE
  m.draw_circle 160,40,"2",Model::CW,Model::NE
  m.draw_circle 60,160,"3",Model::CW,Model::SW
  m.draw_circle 40,40,"4",Model::CCW,Model::NW
  m.draw_dirn
  m.close
end

def render_atail
  m = Model.new  "atail_quad.svg"
  if TFLAT == true
    m.draw_body 40,40,160,40
    m.draw_body 100,40,100,140
  else
    m.draw_body 100,50,40,40
    m.draw_body 100,50,160,40
    m.draw_body 100,50,100,140
  end
  m.draw_body 100,140,140,160
  m.draw_body 100,140,60,160
  m.end_body
  m.draw_circle 60,160,"1",Model::CCW,Model::SW
  m.draw_circle 160,40,"2",Model::CCW,Model::NE
  m.draw_circle 140,160,"3",Model::CW,Model::SE
  m.draw_circle 40,40,"4",Model::CW,Model::NW
  m.draw_dirn
  m.close
end

def render_octox8 # just x8 surely?
  m = Model.new  "octo_x8.svg"

  m.draw_circle 170,170,"5",Model::CCW,Model::NE,false,:dark_green,14,8
  m.draw_circle 170,30,"6",Model::CW,Model::SE,false,:dark_green,-10,8
  m.draw_circle 30,170,"7",Model::CW,Model::NW,false,:dark_green,14,-10
  m.draw_circle 30,30,"8",Model::CCW,Model::SW,false,:dark_green,-10,-10

  m.draw_body 50,50,150,150
  m.draw_body 50,150,150,50
  m.end_body
  m.draw_circle 150,150,"1",Model::CW,Model::SW,"#fff8",nil,-10
  m.draw_circle 150,50,"2",Model::CCW,Model::NW,"#fff8",nil,12
  m.draw_circle 50,150,"3",Model::CCW,Model::SE,"#fff8",nil,-10
  m.draw_circle 50,50,"4",Model::CW,Model::NE,"#fff8",nil,12
  m.draw_dirn
  m.close
end

def render_quadx
  m = Model.new  "quad_x.svg"
  m.draw_body 40,40,160,160
  m.draw_body 40,160,160,40
  m.end_body
  m.draw_circle 160,160,"1",Model::CW,Model::SE
  m.draw_circle 160,40,"2",Model::CCW,Model::NE
  m.draw_circle 40,160,"3",Model::CCW,Model::SW
  m.draw_circle 40,40,"4",Model::CW,Model::NW
  m.draw_dirn
  m.close
end

def render_quadp
  m = Model.new "quad_p.svg"
  m.draw_body 40,100,160,100
  m.draw_body 100,40,100,160
  m.end_body
  m.draw_circle 100,160,"1",Model::CW,Model::SW
  m.draw_circle 160,100,"2",Model::CCW,Model::NE
  m.draw_circle 100,40,"4",Model::CW,Model::NE
  m.draw_circle 40,100,"3",Model::CCW,Model::SW
  m.draw_dirn
  m.close
end

def render_hexp
  s = ShapeFarm.new
  p = s.generate 100, 100, 60, 6

  m = Model.new  "hex_p.svg"
  m.draw_body  *p[0],*p[3]
  m.draw_body  *p[1],*p[4]
  m.draw_body  *p[2],*p[5]
  m.end_body
  m.radius = 24
  m.draw_circle *p[0],"5",Model::CCW,Model::NW
  m.draw_circle *p[1],"2",Model::CW,Model::NE
  m.draw_circle *p[2],"1",Model::CCW,Model::SE
  m.draw_circle *p[3],"6",Model::CW,Model::SW
  m.draw_circle *p[4],"3",Model::CCW,Model::SW
  m.draw_circle *p[5],"4",Model::CW,Model::NW
  m.draw_dirn
  m.close
end

def render_hexx
  s = ShapeFarm.new
  p = s.generate 100, 100, 60, 6, 30

  m = Model.new "hex_x.svg"
  m.draw_body  *p[0],*p[3]
  m.draw_body  *p[1],*p[4]
  m.draw_body  *p[2],*p[5]
  m.end_body
  m.radius = 24
  m.draw_circle *p[0],"2",Model::CCW,Model::NE
  m.draw_circle *p[1],"5",Model::CW,Model::SE
  m.draw_circle *p[2],"1",Model::CCW,Model::SE
  m.draw_circle *p[3],"3",Model::CW,Model::SW
  m.draw_circle *p[4],"6",Model::CCW,Model::SW
  m.draw_circle *p[5],"4",Model::CW,Model::NW
  m.draw_dirn
  m.close
end

def render_octx
  s = ShapeFarm.new
  p = s.generate 100, 100, 70, 8, 22.5

  m = Model.new  "octo_flat_x.svg"
  m.lw = 20
  m.radius = 20
  m.draw_body  *p[0],*p[4]
  m.draw_body  *p[1],*p[5]
  m.draw_body  *p[2],*p[6]
  m.draw_body  *p[3],*p[7]
  m.end_body
  m.draw_circle *p[0],"2",Model::CCW,Model::NE
  m.draw_circle *p[1],"6",Model::CW,Model::NE
  m.draw_circle *p[2],"3",Model::CCW,Model::SE
  m.draw_circle *p[3],"7",Model::CW,Model::SE
  m.draw_circle *p[4],"4",Model::CCW,Model::SW
  m.draw_circle *p[5],"8",Model::CW,Model::SW
  m.draw_circle *p[6],"1",Model::CCW,Model::NW
  m.draw_circle *p[7],"5",Model::CW,Model::NW
  m.draw_dirn
  m.close
end

def render_octp
  s = ShapeFarm.new
  p = s.generate 100, 100, 70, 8

  m = Model.new "octo_flat_p.svg"
  m.lw = 20
  m.radius = 20

  m.draw_body  *p[0],*p[4]
  m.draw_body  *p[1],*p[5]
  m.draw_body  *p[2],*p[6]
  m.draw_body  *p[3],*p[7]
  m.end_body

  m.draw_circle *p[0],"2",Model::CW,Model::NE
  m.draw_circle *p[1],"6",Model::CCW,Model::NE
  m.draw_circle *p[2],"3",Model::CW,Model::SE
  m.draw_circle *p[3],"7",Model::CCW,Model::SE
  m.draw_circle *p[4],"4",Model::CW,Model::SW
  m.draw_circle *p[5],"8",Model::CCW,Model::SW
  m.draw_circle *p[6],"1",Model::CW,Model::NW
  m.draw_circle *p[7],"5",Model::CCW,Model::NW
  m.draw_dirn
  m.close
end

def render_aero
  m = Model.new "airplane.svg"
  m.lw = 1

# For easy? of understanding, split into parts
# Nose
# m.draw_path([[85,20], [80,40], [120,40], [115,20],'!'],:silver, true)
# Wing
#  m.draw_path([[80,40], [20,60], [20,100], [70,80], [130,80], [180,100],
#                [180,60], [120,40],'!'], :silver, true)
# Aft
#  m.draw_path([[80,80],[90,150],[110,150],[120,80],'!'], :silver, true)
# Tail
#  m.draw_path([[90,150], [50,155], [50,175], [150,175], [150,155], [110,150],'!'], :silver, true)

  m.draw_path([[85,20], [80,40], [20,60], [20,100], [70,80],
		[80,80], [90,150], [50,155], [50,175],
		[150,175], [150,155], [110,150],[120,80],[130,80],
		[180,100], [180,60], [120,40], [115,20],'!'],:silver, true)
  m.draw_path([[20,80],[20,100],[70,80],[70,60], '!'], :red)
  m.draw_path([[180,80],[180,100],[130,80],[130,60], '!'], :green)
  m.draw_path([[50,165], [50,175], [150,175], [150,165],'!'],:orange)
  m.draw_path([[100,140], [95,150], [100,175], [105,150],'!'],:black)
  m.end_body
  m.radius = 14
  m.draw_circle 100,15,"1/2",Model::NOARROW,Model::SE, false, nil, 0, -9
  m.draw_servo 30, 100, " 3", :red
  m.draw_servo 142, 100, " 4", :green

  m.draw_servo 64, 134, " 5", :black
  m.draw_servo 154, 168, " 6", :orange
  m.draw_dirn 50
  m.close
end

def render_wing
  m = Model.new "flying_wing.svg"
  m.lw = 1
  m.draw_path([[80,20],[20,80],[20,120],[70,80],[130,80], [180,120],[180,80],
		[120,20],'!'], :silver)
  m.draw_path([[20,100],[20,120],[70,80],[70,60], '!'], :red)
  m.draw_path([[180,100],[180,120],[130,80],[130,60], '!'], :green)

  m.draw_servo 30, 120, " 3", :red
  m.draw_servo 142, 120, " 4", :green
  m.draw_circle 100,110,"1/2",Model::NOARROW,Model::SE, false, nil, 0, -16
  m.draw_dirn 30
  m.close
end

render_bi
render_tri
render_quadx
render_quadp
render_hexp
render_hexx
render_octx
render_octp
render_vtail
render_atail
render_y4
render_y6
render_octox8
render_aero
render_wing
