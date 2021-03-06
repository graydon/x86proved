(** * NOT instruction *)
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

Lemma NOT_rule d (src:RegMem d) v:
  |-- specAtRegMemDst src (fun V => basic (V v) (UOP d OP_NOT src) (V (invB v))).
Proof. do_instrrule_triple. Qed.

Ltac basicNOT :=
  rewrite /makeUOP;
  let R := lazymatch goal with
             | |- |-- basic ?p (@UOP ?d OP_NOT ?a) ?q => constr:(@NOT_rule d a)
           end in
  basicapply R.


(** We open a section in order to localize the hints *)
Section InstrRules.

Hint Unfold
  specAtDstSrc specAtSrc specAtRegMemDst specAtMemSpec specAtMemSpecDst
  DWORDRegMemR BYTERegMemR DWORDRegMemM DWORDRegImmI fromSingletonMemSpec
  DWORDorBYTEregIs natAsDWORD BYTEtoDWORD
  makeMOV makeBOP makeUOP
  : basicapply.
Hint Rewrite
  addB0 low_catB : basicapply.

(** Special case for not *)
Lemma NOT_R_rule (r:Reg) (v:DWORD):
  |-- basic (r~=v) (NOT r) (r~=invB v).
Proof. basicNOT. Qed.

Corollary NOT_M_rule (r:Reg) (offset:nat) (v pbase:DWORD):
  |-- basic (r~=pbase ** pbase +# offset :-> v) (NOT [r + offset])
            (r~=pbase ** pbase +# offset :-> invB v).
Proof. basicNOT. Qed.
End InstrRules.
