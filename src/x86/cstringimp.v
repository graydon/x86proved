(*===========================================================================
    C-style string code
  ===========================================================================*)
Require Import ssreflect ssrbool ssrnat eqtype seq fintype tuple.
Require Import procstate procstatemonad bitsrep bitsops bitsprops bitsopsprops.
Require Import SPred septac spec spectac safe basic basicprog program.
Require Import instr instrsyntax instrcodec instrrules reader pointsto cursor basic flags macros.
Require Import Coq.Strings.String cstring Ascii.

Set Implicit Arguments.
Unset Strict Implicit.
Import Prenex Implicits.

(* String s contains no null characters *)
Fixpoint zeroFree s :=
  if s is String c s' then charToBYTE c != #0 /\ zeroFree s' else True.

Lemma zeroFree_append (s1 s2: string) :
  zeroFree (s1 ++ s2) -> zeroFree s1 /\ zeroFree s2.
Proof. induction s1 => //. simpl; intuition. Qed.

(* A couple of trivial lemmas concerning strings *)
Lemma length_append (s1 s2: string) : length (s1 ++ s2) = length s1 + length s2.
Proof. induction s1 => //. by rewrite /= IHs1. Qed.

Lemma append_cons s1 c s2 : (s1 ++ String c s2 = (s1 ++ String c EmptyString) ++ s2)%string.
Proof. induction s1 => //. by rewrite /= IHs1.  Qed.

(* The bytes between p and q correspond precisely to the contents of string s *)
Fixpoint memIsString (p q: DWORD) (s: string)  :=
  if s is String c s
  then p :-> charToBYTE c ** memIsString (p +# 1) q s
  else p == q /\\ empSP.

(* The memory at [p] contains a null-terminated string [s]
   (Note that [s] should not itself not contain null characters) *)
Fixpoint pointsToCString (p: DWORD) (s: string) : SPred :=
  if s is String c s
  then p :-> charToBYTE c ** pointsToCString (p+#1) s
  else p :-> (#0:BYTE).

Lemma pointsToCStringCons p c s :
  pointsToCString p (String c s) -|- p :-> charToBYTE c ** pointsToCString (p+#1) s.
Proof. split; rewrite /pointsToCString; by ssimpl. Qed.

(* If [p] points to a C-string [prefix ++ suffix] then it can be split into memory
   from [p] to [p +# length prefix] containing [prefix] and [p +# length prefix]
   pointing to [suffix] *)
Lemma pointsToCString_append prefix : forall p suffix,
  pointsToCString p (prefix ++ suffix) |--
  memIsString p (p +# length prefix) prefix ** pointsToCString (p +# length prefix) suffix.
Proof. induction prefix => p suffix.
+ simpl (_ ++ _).  rewrite /memIsString. simpl (length _). rewrite addB0/=. sbazooka.
+ rewrite /memIsString-/memIsString pointsToCStringCons -/append.
rewrite -> IHprefix. simpl (length _). ssimpl. by rewrite -addB_addn add1n.
Qed.

Lemma pointsToCString_append_op prefix : forall p q suffix,
  memIsString p q prefix ** pointsToCString q suffix |--
  pointsToCString p (prefix ++ suffix).
Proof. induction prefix => p q suffix.
+ rewrite /=. sdestructs => /eqP ->. by ssimpl.
+ rewrite /=. ssimpl. by rewrite <- (IHprefix (p+#1) q).
Qed.


(* Given a pointer to a C-style string in EDI, return its length in ECX *)
Definition strlen : program :=
  (MOV ECX, 0;;
   while (CMP BYTE [EDI + ECX + 0], #0) CC_Z false
     (INC ECX))%asm.

(* Correctness of strlen *)
Lemma strlen_correct p s :
  zeroFree s ->
  |-- basic ECX? strlen (ECX ~= #(length s))
    @ (OSZCP? ** EDI ~= p ** pointsToCString p s).
Proof.
  move => ISZF. rewrite /strlen.
  autorewrite with push_at.

  unhideReg ECX => oldecx.

  (* MOV ECX, 0 *)
  basicapply MOV_RI_rule. rewrite /stateIsAny. sbazooka.

  (* WHILE *)
  (* Loop invariant is most easily expressed by splitting the string into
     a prefix and suffix. ECX contains the length of the prefix *)
  set (I := fun b =>
    Exists prefix, Exists suffix,
    s = (prefix ++ suffix)%string /\\ (if suffix is ""%string then true else false) == b /\\
    EDI ~= p ** ECX ~= #(length prefix) **
    pointsToCString p s ** OF? ** SF? ** CF? ** PF?).
  eapply basic_basic; first apply (while_rule_ro (I:=I)). (*first 2 last. *)

  (* Condition code: CMP [EDX+ECX], 0 *)
  specintros => b1 b2.
  subst I; cbv beta.
  specintros => prefix suffix APPEND END.

  case E: suffix => [| a s'].

  (* Empty string *)
  + rewrite /ConditionIs.
  eapply basic_basic; first eapply CMP_MbxI_ZC_rule.
  rewrite /stateIsAny/ConditionIs.
  subst. rewrite -> pointsToCString_append. rewrite /pointsToCString.
  sbazooka. subst. sbazooka. rewrite <-pointsToCString_append_op.
  rewrite /pointsToCString. rewrite /stateIsAny. sbazooka.

  (* Non-empty string *)
  + subst. rewrite /ConditionIs.
  eapply basic_basic; first eapply CMP_MbxI_ZC_rule.
  rewrite /stateIsAny/ConditionIs.
  subst. rewrite -> pointsToCString_append. rewrite /pointsToCString-/pointsToCString.
  sbazooka.
  sbazooka.
    red. destruct (zeroFree_append ISZF) as [_ [ZFM _]].
    by rewrite eq_sym eqbF_neg.
    rewrite <- pointsToCString_append_op. rewrite /pointsToCString-/pointsToCString/stateIsAny. sbazooka.

  (* Body of loop: INC ECX *)
  rewrite /ConditionIs/I.
  specintros => prefix suffix APPEND END. rewrite /stateIsAny. specintros => ofl sfl cfl pfl.
  subst.
  eapply basic_basic. eapply INC_R_rule.
  rewrite /OSZCP. sbazooka.

  case E: suffix => [| a s'].

  (* Empty string *)
  + by subst.
  (* Non-empty string *)
  + subst. ssplit. ssplit. instantiate (1:= (prefix ++ String a EmptyString)%string).
    rewrite /OSZCP. sbazooka.
    by rewrite append_cons.
    rewrite length_append. simpl (length _). rewrite incB_fromNat addn1. by ssimpl.

  (**)
  subst I.
    rewrite /ConditionIs.
    rewrite /stateIsAny.
    sdestructs => o sf z c pf. sbazooka. instantiate (1:=s). by instantiate (1:=EmptyString).
    simpl (length _). rewrite /natAsDWORD. by ssimpl.
  subst I; cbv beta.
    sdestructs => prefix suffix -> END.
    rewrite /ConditionIs.
    destruct suffix => //.
    rewrite /stateIsAny. rewrite length_append addn0.
    sbazooka.
Qed.

