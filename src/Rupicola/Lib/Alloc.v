Require Import Rupicola.Lib.SeparationLogicImpl.
Require Import Rupicola.Lib.Core.
Require Import Rupicola.Lib.Notations.

Local Open Scope Z_scope.

Section with_parameters.  
  Context {width: Z} {BW: Bitwidth width} {word: word.word width} {mem: map.map word Byte.byte}.
  Context {locals: map.map String.string word}.
  Context {env: map.map String.string (list String.string * list String.string * Syntax.cmd)}.
  Context {ext_spec: bedrock2.Semantics.ExtSpec}.
  Context {word_ok : word.ok word} {mem_ok : map.ok mem}.
  Context {locals_ok : map.ok locals}.
  Context {env_ok : map.ok env}.
  Context {ext_spec_ok : Semantics.ext_spec.ok ext_spec}.

  (* To enable allocation of A terms via the predicate P, implement this class *)
  (* I is a type if indices to use if P can take additional arguments *)
  Class Allocable {I A} (P : I -> word.rep -> A -> mem -> Prop) :=
    {
    size_in_bytes : Z;
    size_in_bytes_mod
    : size_in_bytes mod Memory.bytes_per_word width = 0;
    P_to_bytes
    : forall px i x,
        Lift1Prop.impl1 (P i px x) (Memory.anybytes px size_in_bytes);
    P_from_bytes
    : forall px,
        Lift1Prop.impl1 (Memory.anybytes px size_in_bytes)
                        (Lift1Prop.ex1 (fun i => Lift1Prop.ex1 (P i px)))
    }.

  (* FIXME if we need to roundtrip:

     Class Allocable {A} (P : word.rep -> A -> mem -> Prop) :=
       { alloc_sz: Z;
         alloc_length_ok bs := Z.of_nat (List.length bs) = alloc_sz;
         alloc_sz_ok : alloc_sz mod Memory.bytes_per_word width = 0;

         alloc_to_bytes : A -> list byte;
         alloc_of_bytes : forall bs: list byte, alloc_length_ok bs -> A;

         alloc_to_bytes_length_ok a: alloc_length_ok (alloc_to_bytes a);

         alloc_to_bytes_ok ptr bs:
           Lift1Prop.impl1
             (P ptr bs)
             (array ptsto (word.of_Z 1) ptr (alloc_to_bytes bs));
         alloc_of_bytes_ok ptr bs (Hlen: alloc_length_ok bs) :
           Lift1Prop.impl1
             (array ptsto (word.of_Z 1) ptr bs)
             (P ptr (alloc_of_bytes bs Hlen)) }.

     Lemma alloc_of_bytes_to_bytes
           {A} (P : word.rep -> A -> mem -> Prop)
           `{Allocable _ P} a Hlen:
       alloc_of_bytes (alloc_to_bytes a) Hlen = a.
     Proof. … Qed. *)

  Class SimpleAllocable {A} (P : word.rep -> A -> mem -> Prop) :=
    { ssize_in_bytes : Z;
      ssize_in_bytes_mod :
        ssize_in_bytes mod Memory.bytes_per_word width = 0;
      sP_to_bytes px x :
        Lift1Prop.impl1 (P px x) (Memory.anybytes px ssize_in_bytes);
      sP_from_bytes px :
        Lift1Prop.impl1 (Memory.anybytes px ssize_in_bytes)
                        (Lift1Prop.ex1 (P px)) }.

  Instance Allocable_of_SimpleAllocable {A} (P : word.rep -> A -> mem -> Prop)
           {H: SimpleAllocable P} : Allocable (fun _: unit => P).
  Proof.
    refine {| size_in_bytes := ssize_in_bytes;
              size_in_bytes_mod := ssize_in_bytes_mod;
              P_to_bytes := _;
              P_from_bytes := _ |}; intros.
    - apply sP_to_bytes.
    - abstract (red; exists tt; apply sP_from_bytes; assumption).
  Defined.

  Program Instance SimpleAllocable_scalar : SimpleAllocable scalar :=
    {| ssize_in_bytes := Memory.bytes_per_word width;
       ssize_in_bytes_mod := Z_mod_same_full _;
       sP_to_bytes := scalar_to_anybytes;
       sP_from_bytes := anybytes_to_scalar |}.

  Definition pred_sep {A} R (pred : A -> predicate) (v : A) tr' mem' locals':=
    (R * (fun mem => pred v tr' mem locals'))%sep mem'.

  (* identity used as a marker to indicate when something should be allocated *)
  (*TODO: should this require finding the instance? probably not
   Definition alloc {p : Semantics.parameters} {A} {P : A -> @Semantics.mem p -> Prop} `{@Allocable p A P} (a : A) := a. *)
  Definition alloc {A} (a : A) := a. 
  Definition simple_alloc {A} (a : A) := a.

  Lemma compile_alloc
        {tr m l functions A} (v : A):
    forall {P} {pred: P v -> predicate} {k: nlet_eq_k P v} {k_impl}
           {I} {AP : I -> word.rep -> A -> map.rep -> Prop} `{Allocable I A AP}
           (R: mem -> Prop) out_var,

      R m ->

      (forall i out_ptr uninit m',
         sep (AP i out_ptr uninit) R m' ->
         (<{ Trace := tr;
             Memory := m';
             Locals := map.put l out_var out_ptr;
             Functions := functions }>
          k_impl
          <{ pred_sep (Memory.anybytes out_ptr size_in_bytes) pred (nlet_eq [out_var] v k) }>)) ->
      <{ Trace := tr;
         Memory := m;
         Locals := l;
         Functions := functions }>      
      cmd.stackalloc out_var size_in_bytes k_impl
      <{ pred (nlet_eq [out_var] (alloc v) k) }>.
  Proof.
    repeat straightline.
    split; eauto using size_in_bytes_mod.
    intros out_ptr mStack mCombined Hplace%P_from_bytes.
    destruct Hplace as [i [out Hout]].
    repeat straightline.
    specialize (H1 i out_ptr out mCombined).     
    eapply WeakestPrecondition_weaken
      with (p1 := pred_sep (Memory.anybytes out_ptr size_in_bytes)
                           pred (let/n x as out_var eq:Heq := v in
                                 k x Heq)).
    2:{
      eapply H1.
      exists mStack;
        exists m;
        intuition.
      apply map.split_comm; eauto.
    }
    {
      clear H1.
      unfold pred_sep;
        unfold Basics.flip;
        simpl.
      intros.
      destruct H1 as [mem1 [mem2 ?]].
      exists mem2; exists mem1;
        intuition.
      apply map.split_comm; eauto.
    }
  Qed.

  Lemma compile_simple_alloc {tr m l functions A} (v : A):
    forall {P} {pred: P v -> predicate} {k: nlet_eq_k P v} {k_impl}
      {AP : word.rep -> A -> map.rep -> Prop} `{SimpleAllocable A AP}
      (R: mem -> Prop) out_var,

      R m ->

      (forall out_ptr uninit m',
          sep (AP out_ptr uninit) R m' ->
          <{ Trace := tr;
             Memory := m';
             Locals := map.put l out_var out_ptr;
             Functions := functions }>
          k_impl
          <{ pred_sep (Memory.anybytes out_ptr size_in_bytes)
                      pred (nlet_eq [out_var] v k) }>) ->
      <{ Trace := tr;
         Memory := m;
         Locals := l;
         Functions := functions }>
      cmd.stackalloc out_var size_in_bytes k_impl
      <{ pred (nlet_eq [out_var] (simple_alloc v) k) }>.
  Proof.
    intros; eapply compile_alloc; eauto.
  Qed.
End with_parameters.

Arguments alloc : simpl never.
Arguments simple_alloc : simpl never.
Arguments size_in_bytes : simpl never.

(*TODO: speed up by combining pred_seps first and using 1 proper/ecancel_assumption?*)
Ltac clear_pred_seps :=   
  unfold pred_sep;
  repeat change (fun x => ?h x) with h;
  repeat match goal with
         | [ H : _ ?m |- _ ?m] =>
           eapply Proper_sep_impl1;
           [ eapply P_to_bytes | clear H m; intros H m | ecancel_assumption]
         end.

(* FIXME I don't think eassumption is needed, and there might actually be multiple ?R m *)
#[export] Hint Extern 10 =>
  simple eapply compile_alloc; [eassumption | shelve] : compiler.
#[export] Hint Extern 10 =>
  simple eapply compile_simple_alloc; shelve : compiler.
#[export] Hint Extern 1 (pred_sep _ _ _ _ _ _) =>
  clear_pred_seps; shelve : compiler_cleanup_post.
