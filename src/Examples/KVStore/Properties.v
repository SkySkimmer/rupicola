Require Import Coq.ZArith.ZArith.
Require Import Coq.Strings.String.
Require Import Coq.Lists.List.
Require Import Coq.micromega.Lia.
Require Import bedrock2.Array.
Require Import bedrock2.BasicCSyntax.
Require Import bedrock2.BasicC64Semantics.
Require Import bedrock2.ProgramLogic.
Require Import bedrock2.Scalars.
Require Import bedrock2.Syntax.
Require Import bedrock2.WeakestPreconditionProperties.
Require Import bedrock2.Map.Separation.
Require Import bedrock2.Map.SeparationLogic.
Require Import bedrock2.NotationsCustomEntry.
Require Import coqutil.Word.Interface coqutil.Word.Properties.
Require Import coqutil.Map.Interface coqutil.Map.Properties.
Require Import Rupicola.Examples.KVStore.KVStore.
Local Open Scope string_scope.
Import ListNotations.

Section properties.
  Context {ops key value Value}
          {kvp : kv_parameters}
          {ok : @kv_parameters_ok ops key value Value kvp}.
  Existing Instances map_ok annotated_map_ok key_eq_dec.

  Lemma Map_put_iff1 :
    forall value Value pm (m : map.rep (map:=map_gen value))
           k v1 v2 R1 R2,
      (forall pv,
          Lift1Prop.iff1
            (sep (Value pv v1) R1)
            (sep (Value pv v2) R2)) ->
      Lift1Prop.iff1
        (sep (Map_gen value Value pm (map.put m k v1)) R1)
        (sep (Map_gen value Value pm (map.put m k v2)) R2).
  Proof.
    intros *.
    intro Hiff; split; intros;
      eapply Map_put_impl1; intros; eauto;
        rewrite Hiff; reflexivity.
  Qed.

  Definition annotate (m : map) : annotated_map :=
    map.fold (fun m' k v => map.put m' k (Owned, v)) map.empty m.

  Lemma annotate_get_None m k :
    map.get m k = None -> map.get (annotate m) k = None.
  Proof.
    cbv [annotate]; eapply map.fold_spec; intros;
      try eapply map.get_empty; [ ].
    rewrite map.get_put_dec.
    match goal with H : map.get (map.put _ ?k1 _) ?k2 = None |- _ =>
                    rewrite map.get_put_dec in H;
                      destruct (key_eqb k1 k2); try congruence; [ ]
    end.
    eauto.
  Qed.

  Lemma annotate_get_Some m k v :
    map.get m k = Some v ->
    map.get (annotate m) k = Some (Owned, v).
  Proof.
    cbv [annotate]; eapply map.fold_spec;
      rewrite ?map.get_empty; intros; [ congruence | ].
    rewrite map.get_put_dec.
    match goal with H : map.get (map.put _ ?k1 _) ?k2 = Some _ |- _ =>
                    rewrite map.get_put_dec in H;
                      destruct (key_eqb k1 k2); try congruence; [ ]
    end.
    eauto.
  Qed.

  Lemma annotate_get_full m k :
    map.get (annotate m) k = match map.get m k with
                             | Some v => Some (Owned, v)
                             | None => None
                             end.
  Proof.
    break_match; eauto using annotate_get_None, annotate_get_Some.
  Qed.

  Lemma annotate_iff1 pm m :
    Lift1Prop.iff1
      (Map pm m) (AnnotatedMap pm (annotate m)).
  Proof.
    apply Map_fold_iff1; intros; reflexivity.
  Qed.

  Lemma unannotate_iff1 pm m :
    Lift1Prop.iff1
      (AnnotatedMap pm (annotate m)) (Map pm m).
  Proof. symmetry; apply annotate_iff1. Qed.

  Lemma reserved_borrowed_iff1 pm m k pv v :
    Lift1Prop.iff1
      (AnnotatedMap pm (map.put m k (Reserved pv, v)))
      (sep (AnnotatedMap pm (map.put m k (Borrowed pv, v)))
           (Value pv v)).
  Proof.
    cbv [AnnotatedMap].
    rewrite <-sep_emp_True_r.
    apply Map_put_iff1. intros.
    rewrite sep_emp_True_r.
    reflexivity.
  Qed.

  Lemma reserved_owned_impl1 pm m k pv v :
    Lift1Prop.impl1
      (AnnotatedMap pm (map.put m k (Reserved pv, v)))
      (AnnotatedMap pm (map.put m k (Owned, v))).
  Proof.
    rewrite <-(sep_emp_True_r (_ (map.put _ _ (Reserved _, _)))).
    rewrite <-(sep_emp_True_r (_ (map.put _ _ (Owned, _)))).
    cbv [AnnotatedMap]. repeat intro.
    eapply Map_put_impl1; intros; [ | eassumption ].
    cbn [AnnotatedValue_gen fst snd].
    rewrite !sep_emp_True_r.
    intro; rewrite sep_emp_l; intros;
      repeat match goal with
             | H : _ /\ _ |- _ => destruct H
             end;
      subst; eauto.
  Qed.
End properties.
