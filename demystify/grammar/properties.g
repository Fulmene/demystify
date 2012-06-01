parser grammar properties;

// This file is part of Demystify.
// 
// Demystify: a Magic: The Gathering parser
// Copyright (C) 2012 Benjamin S Wolf
// 
// Demystify is free software; you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published
// by the Free Software Foundation; either version 3 of the License,
// or (at your option) any later version.
// 
// Demystify is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
// 
// You should have received a copy of the GNU Lesser General Public License
// along with Demystify.  If not, see <http://www.gnu.org/licenses/>.

/* Rules for describing object properties. */

/*
 * We divide properties into three categories:
 * - adjectives
 * - nouns
 * - descriptors
 *
 * Nouns are the only required part of a set of subset properties
 * (except for the cases where an ability talks about having or being a
 *  property).
 * An adjective is any property that can't be used alone in a subset that
 * precede any nouns. For example, colors and tap status.
 * Descriptors are properties that can't be used alone in a subset that follow
 * any nouns. For example, "under your control" and "named X".
 *
 * Some of these items can be written as lists of two or more items joined
 * with a conjunction. However, the top level properties cannot have a list
 * of more than two; this kind of list will be accomplished by subset lists.
 * Furthermore, only one list can exist per properties set: either the
 * adjective list, the noun list, or the properties pair.
 *
 * When a list occurs in either adjectives or nouns, the list is treated
 * as its own set of properties, joined with the other two categories.
 * The object must match each category for the object to match the whole set
 * of properties. For example, in "white or blue creature", "white or blue"
 * is an adjective list, and creature is a noun. An object must match "white
 * or blue" and "creature" to match this properties set.
 */

properties : a+=adjective*
             ( adj_list? noun+ descriptor*
               -> ^( PROPERTIES adjective* adj_list? noun* descriptor* )
             | noun_list noun* descriptor*
               -> ^( PROPERTIES adjective* noun_list noun* descriptor* )
             | b+=noun+ 
               ( ( COMMA ( c+=properties_case3_ COMMA )+ )?
                 j=conj g=properties_case3_ e+=descriptor*
                 { self.emitDebugMessage('properties case 3: {}'
                                         .format(' '.join(
                    [t.text for t in ($a or []) + ($b or [])]
                    + [', ' + t.toStringTree() for t in ($c or [])]
                    + ($c and [','] or [])
                    + [$j.text]
                    + [$g.text]
                    + [t.toStringTree() for t in ($e or [])]))) }
                 -> ^( PROPERTIES ^( $j ^( AND $a* $b+ )
                                        ^( AND properties_case3_)+ )
                                     descriptor* )
                 // TODO: expand case 4 if necessary?
               | f+=descriptor+ k=conj c+=adjective* d+=noun+ e+=descriptor*
                 { self.emitDebugMessage('properties case 4: {}'
                                         .format(' '.join(
                    [t.text for t in ($a or []) + ($b or [])]
                    + [t.toStringTree() for t in ($f or [])]
                    + [$k.text]
                    + [t.text for t in ($c or []) + ($d or [])]
                    + [t.toStringTree() for t in ($e or [])]))) }
                 -> ^( PROPERTIES ^( $k ^( AND $a* $b+ $f+ )
                                        ^( AND $c* $d+ $e* ) ) )
               )
             );

properties_case3_ : adjective+ noun+ ;

simple_properties : adjective* noun+ -> ^( PROPERTIES adjective* noun+ )
                  | adjective+ -> ^( PROPERTIES adjective+ );

// Lists

adj_list : adjective ( COMMA! ( ( adjective | noun ) COMMA! )+ )?
           conj^ ( adjective | noun );

noun_list : noun ( COMMA! ( noun COMMA! )+ )? conj^ noun ;

// Adjectives

adjective : NON? ( supertype | color | color_spec | status )
            -> {$NON}? ^( NON[] supertype? color? color_spec? status? )
            -> supertype? color? color_spec? status? ;

color : WHITE | BLUE | BLACK | RED | GREEN;
color_spec : COLORED | COLORLESS | MONOCOLORED | MULTICOLORED;
status : TAPPED
       | UNTAPPED
       | SUSPENDED
       | ATTACKING
       | BLOCKING
       | BLOCKED
       | UNBLOCKED
       | FACE_UP
       | FACE_DOWN
       | FLIPPED
       | REVEALED
       ;
// status that can't be used as an adjective but can be used in descriptors
desc_status : status
            | ENCHANTED
            | EQUIPPED
            | FORTIFIED
            ;

// Nouns

noun : NON? ( type | obj_subtype | obj_type )
       -> {$NON}? ^( NON[] type? obj_subtype? obj_type? )
       -> type? obj_subtype? obj_type? ;

// Descriptors

descriptor : named
           | control
           | own
           | cast
           | in_zones
           | with_keywords
           | THAT ( ISNT | ARENT )
             ( desc_status | in_zones | ON spec_zone )
             -> ^( NOT desc_status? in_zones? spec_zone? )
           ;

named : ( NOT -> ^( NOT ^( NAMED[] REFBYNAME ) )
        | -> ^( NAMED[] REFBYNAME )
        ) NAMED REFBYNAME
        ;

control : player_subset DONT? CONTROL
          -> {$DONT}? ^( NOT ^( CONTROL[] player_subset ) )
          -> ^( CONTROL[] player_subset );
own : player_subset DONT? OWN
      -> {$DONT}? ^( NOT ^( OWN[] player_subset ) )
      -> ^( OWN[] player_subset );
cast : player_subset DONT? CAST
       -> {$DONT}? ^( NOT ^( CAST[] player_subset ) )
       -> ^( CAST[] player_subset );

in_zones : ( IN | FROM ) zone_subset -> ^( IN[] zone_subset );

with_keywords : WITH raw_keywords -> ^( KEYWORDS raw_keywords )
              | WITHOUT raw_keywords -> ^( NOT ^( KEYWORDS raw_keywords ) )
              ;

/* Special references to related objects. */

// TODO: target
// TODO: ref_player
ref_object : SELF
           | PARENT
           | IT
           | THEM
             // planeswalker pronouns
           | HIM
           | HER
             // We probably don't actually need to remember what the
             // nouns were here, but keep them in for now.
           | ( ENCHANTED | EQUIPPED | FORTIFIED | HAUNTED ) noun+
           | this_guy
           ;

// eg. this creature, this permanent, this spell.
this_guy : THIS ( type | obj_type ) -> SELF;

/* Property names. */

prop_types : prop_type ( ( COMMA! ( prop_type COMMA! )+ )? conj^ prop_type )? ;

prop_type : COLOR
          | MANA! COST
          | type TYPE -> ^( SUBTYPE type )
          | CARD!? TYPE
          | int_prop;

int_prop : CONVERTED MANA COST -> CMC
         | LIFE TOTAL!?
         | POWER
         | TOUGHNESS;
