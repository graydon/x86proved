(** * JMP (rel) instruction *)
Require Import ssreflect ssrbool ssrnat ssrfun eqtype seq fintype tuple.
Require Import procstate procstatemonad bitsops bitsprops bitsopsprops.
Require Import spec SPred septac spec safe triple basic basicprog spectac.
Require Import instr instrcodec eval monad monadinst reader pointsto cursor.
Require Import Setoid RelationClasses Morphisms.

Set Implicit Arguments.
Unset Strict Implicit.
Import Prenex Implicits.

Require Import Relations.
Require Import instrsyntax.

Local Open Scope instr_scope.

Require Import x86.instrrules.core.

Lemma JMPrel_rule (tgt: JmpTgt) (p q: DWORD) :
  |-- interpJmpTgt tgt q (fun P addr =>
     (|> safe @ (EIP ~= addr ** P) -->> safe @ (EIP ~= p ** P)) <@ (p -- q :-> JMPrel tgt)).
Proof.
  rewrite /interpJmpTgt/interpMemSpecSrc.
  do_instrrule
    ((try specintros => *; autorewrite with push_at);
     apply TRIPLE_safe => ?;
     do !instrrule_triple_bazooka_step idtac).
Qed.

Section specapply_hint.
Local Hint Unfold interpJmpTgt : specapply.

Lemma JMPrel_I_rule rel (p q: DWORD) :
  |-- (|> safe @ (EIP ~= addB q rel) -->> safe @ (EIP ~= p)) <@
        (p -- q :-> JMPrel (mkTgt rel)).
Proof.
  specapply (JMPrel_rule (JmpTgtI (mkTgt rel))). by ssimpl.

  autorewrite with push_at. rewrite <-spec_reads_frame. apply limplValid.
  cancel1. cancel1. sbazooka.
Qed.

Lemma JMPrel_R_rule (r:Reg) addr (p q: DWORD) :
  |-- (|> safe @ (EIP ~= addr ** r ~= addr) -->> safe @ (EIP ~= p ** r ~= addr)) <@
        (p -- q :-> JMPrel (JmpTgtR r)).
Proof.
  specapply (JMPrel_rule (JmpTgtR r)). by ssimpl.

  rewrite <-spec_reads_frame. autorewrite with push_at. rewrite limplValid.
  cancel1. cancel1. sbazooka.
Qed.
End specapply_hint.
