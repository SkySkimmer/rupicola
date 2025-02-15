Require Import Rupicola.Lib.Api.
Require Import Rupicola.Lib.Conditionals.

Section with_parameters.
  Context {width: Z} {BW: Bitwidth width} {word: word.word width} {mem: map.map word Byte.byte}.
  Context {locals: map.map String.string word}.
  Context {env: map.map String.string (list String.string * list String.string * Syntax.cmd)}.
  Context {ext_spec: bedrock2.Semantics.ExtSpec}.
  Context {word_ok : word.ok word} {mem_ok : map.ok mem}.
  Context {locals_ok : map.ok locals}.
  Context {env_ok : map.ok env}.
  Context {ext_spec_ok : Semantics.ext_spec.ok ext_spec}.

  Implicit Type R : mem -> Prop.

  Section Tail.
    Definition min (x y : word) :=
      let/n c := word.ltu x y in
      if c then
        let/n r := x in r
      else
        let/n r := y in r.

    Instance spec_of_min : spec_of "min" :=
      fnspec! "min" (x y: word) ~> z,
      { requires tr mem := True;
        ensures tr' mem' := tr = tr' /\ mem = mem' /\ z = min x y }.

    Hint Extern 2 (IsRupicolaBinding (if _ then _ else _)) => exact true : typeclass_instances.
    Local Hint Extern 1 => simple eapply compile_tail_if; shelve : compiler.

    Derive min_body SuchThat
           (defn! "min"("x", "y") ~> "r"
                { min_body },
            implements min)
           As min_body_correct.
    Proof.
      compile.
    Qed.
  End Tail.

  Section Body.
    Definition minm (x y : word) :=
      let/n c := word.ltu x y in
      let/n r := if c then x
                else word.add y (word.of_Z 1) in
      let/n r := word.sub r (word.of_Z 1) in
      r.

    Instance spec_of_minm : spec_of "minm" :=
      fnspec! "minm" (x y: word) / R ~> z,
      { requires tr mem := R mem;
        ensures tr' mem' := tr = tr' /\ R mem' /\ z = minm x y }. (* TODO explain why not mem; = mem *)

    Hint Extern 1 => compile_if; shelve : compiler.

    Derive minm_body SuchThat
           (defn! "minm"("x", "y") ~> "r"
                { minm_body },
            implements minm)
           As minm_body_correct.
    Proof.
      compile.
    Qed.
  End Body.
End with_parameters.
