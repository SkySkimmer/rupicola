Require Import Rupicola.Lib.Core.
Require Import Rupicola.Lib.Notations.
Require Export Rupicola.Lib.Gensym.

Lemma compile_skip :
  forall (locals: Semantics.locals) (mem: Semantics.mem)
    tr R functions T (pred: T -> _ -> Prop) head,
    sep (pred head) R mem ->
    (find cmd.skip
     implementing (pred head)
     with-locals locals and-memory mem and-trace tr and-rest R
     and-functions functions).
Proof.
  intros.
  repeat straightline.
  red; red; eauto.
Qed.

Lemma compile_constant :
  forall (locals: Semantics.locals) (mem: Semantics.mem)
    tr R functions T (pred: T -> _ -> Prop) z k k_impl,
  forall var,
    let v := word.of_Z z in
    (let head := v in
     find k_impl
     implementing (pred (k head))
     with-locals (map.put locals var head)
     and-memory mem and-trace tr and-rest R
     and-functions functions) ->
    (let head := v in
     find (cmd.seq (cmd.set var (expr.literal z)) k_impl)
     implementing (pred (dlet head k))
     with-locals locals and-memory mem and-trace tr and-rest R
     and-functions functions).
Proof.
  intros.
  repeat straightline.
  eassumption.
Qed.

(* FIXME add let pattern to other lemmas *)
Lemma compile_add :
  forall (locals: Semantics.locals) (mem: Semantics.mem)
    tr R (* R' *) functions T (pred: T -> _ -> Prop) x x_var y y_var k k_impl,
  forall var,
    (* WeakestPrecondition.dexpr mem locals (expr.var x_var) x -> *)
    (* WeakestPrecondition.dexpr mem locals (expr.var y_var) y -> *)
    map.get locals x_var = Some x ->
    map.get locals y_var = Some y ->
    let v := word.add x y in
    (let head := v in
     find k_impl
     implementing (pred (k head))
     with-locals (map.put locals var head)
     and-memory mem and-trace tr and-rest R
     and-functions functions) ->
    (let head := v in
     find (cmd.seq (cmd.set var (expr.op bopname.add (expr.var x_var) (expr.var y_var)))
                   k_impl)
     implementing (pred (dlet head k))
     with-locals locals and-memory mem and-trace tr and-rest R
     and-functions functions).
Proof.
  intros.
  repeat straightline.
  eexists; split.
  { repeat straightline.
    exists x; split; try eassumption.
    repeat straightline.
    exists y; split; try eassumption.
    reflexivity. }
  red.
  eassumption.
Qed.

Ltac setup_step :=
  match goal with
  | _ => progress (cbv zeta; unfold program_logic_goal_for)
  | [  |- forall _, _ ] => intros
  | [  |- exists _, _ ] => eexists
  | [  |- _ /\ _ ] => split
  | [  |- context[postcondition_for _ _ _] ] =>
    set (postcondition_for _ _ _)
  | _ => reflexivity
  | _ => cbn
  end.

Ltac term_head x :=
  match x with
  | ?f _ => term_head f
  | _ => x
  end.

Ltac setup :=
  repeat setup_step;
  repeat match goal with
         | [ H := _ |- _ ] => subst H
         end;
  match goal with
  | [  |- context[postcondition_for (?pred ?spec) ?R ?tr] ] =>
    change (fun x y _ => postcondition_for (pred spec) R tr x y [])
      with (postcondition_norets (pred spec) R tr);
    let hd := term_head spec in
    unfold hd
  end.

Ltac lookup_variable locals ptr :=
  lazymatch locals with
  | [] => fail
  | (?k, ptr) :: _ => k
  | (_, _) :: ?tl => lookup_variable tl ptr
  end.

Ltac solve_map_get_goal :=
  lazymatch goal with
  | [  |- map.get {| value := ?locals; _value_ok := _ |} _ = Some ?val ] =>
    let var := lookup_variable locals val in
    instantiate (1 := var);
    reflexivity
  end.

Create HintDb compiler.

Ltac compile_basics :=
  (* FIXME compile_skip applies in all cases, so guard it *)
  gen_sym_inc;
  let name := gen_sym_fetch "v" in
  first [simple eapply compile_constant with (var := name) |
         simple eapply compile_add with (var := name) |
         simple eapply compile_skip].

Ltac compile_custom := fail.

Ltac compile_step :=
  lazymatch goal with
  | [  |- let _ := _ in _ ] => intros
  | [  |- context[map.put _ _ _] ] => simpl map.put
  | [  |- WeakestPrecondition.cmd _ _ _ _ _ _ ] =>
    first [compile_custom | compile_basics ]
  | [  |- sep _ _ _ ] =>
    autounfold with compiler in *;
    cbn [fst snd] in *;
    ecancel_assumption
  | [  |- map.get _ _ = Some _ ] => solve_map_get_goal
  | _ => eauto with compiler
  end.

Ltac compile :=
  setup; repeat compile_step.