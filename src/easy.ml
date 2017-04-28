open System

(*************************** Common parameter *************************************)
module type SchedulerParam = sig
  val jobs : job_table
end

(***************************Primary and backfilling selectors***********************)

(**** Primary Selector ****)
module type Primary = sig
  val reorder :
    system:System.system ->        (*system state before primary jobs are started*)
    now:int ->                     (*now*)
    int list->                     (*jobs to reorder*)
    int list
end

module MakeGreedyPrimary
  (C:Metrics.Criteria)
  (S:SchedulerParam)
  : Primary =
struct
  let crit = C.criteria S.jobs
  let reorder ~system:s ~now:now =
    let comp i1 i2 = compare (crit s now i2) (crit s now i1)
    in List.sort comp
end

(**** Backfilling Selector ****)
module type Secondary = sig
  val pick :
    system:system ->                (*full state of the system BEFORE starting easy*)
    now:int ->                      (*now*)
    backfillable:int list ->        (*backfillable jobs*)
    reservationWait:int ->          (*time of the reservation*)
    reservationID:int ->            (*reservation job*)
    reservationFree:int ->          (*free resources above the reservation job*)
    freeNow:int ->                  (*free resources before backfilling*)
    int list
end

module MakeGreedySecondary
  (C:Metrics.Criteria)
  (S:SchedulerParam)
  : Secondary =
struct
  let crit = C.criteria S.jobs
  let pick
        ~system:s
        ~now:now
        ~backfillable:bfable
        ~reservationWait:restime
        ~reservationID:resjob
        ~reservationFree:resres
        ~freeNow:free =
    []
(*let rec argmax v ip = function*)
(*|i::is when v <= (crit s now i) -> argmax (crit s now i) i is*)
(*|i::is -> argmax v ip is*)
(*|[] -> ip*)
(*and id = List.hd bfable*)
(*in argmax (crit s now id) id bfable*)
end


(*let bfchoices =*)
(*Secondary.selector ~system:s ~now:now ~backfillable:bfable*)
(*~reservationWait:resaWait ~reservationID:id ~reservationFree:resaFree*)
(*in let () = assert (List.mem idpicked bfable)*)
(*in let j = fj idpicked*)
(*in let res = j.q*)
(*in let runt = j.p_est*)
(*in let new_f  = f-res*)
(*in let new_f' = if (runt > resaWait) then f'-res else f'*)
(*in let remaining_ids = List.filter (fun id -> id != idpicked) bfable*)
(*in picknext (decisionlist@[(idpicked)]) new_f new_f' remaining_ids*)


(************************************ Scheduler ***************************************)
module type Scheduler = sig
  val schedule : int -> System.system -> int list
end

module MakeEasyScheduler
  (Primary:Primary)
  (Secondary:Secondary)
  (P:SchedulerParam)
  : Scheduler =
struct
  let fj = Hashtbl.find P.jobs

  (*should we attempt to backfill?*)
  type easy =
      Simple of int list      (*no backfilling needed*)
    | Backfill of (int list * (*to start now*)
                   int *      (*remaining resources after*)
                   int *      (*id of job to backfill*)
                   int list)  (*pontentially eligible*)
  let get_easy ~free:free ~waitqueue:wq =
    assert (free >= 0);
    let rec easy decision free = function
      | [] -> Simple decision
      | i :: is  -> let remaining = free-(fj i).q
        in if remaining >= 0 then easy (decision@[i]) remaining is
        else Backfill (decision,free,i,is)
    in easy [] free wq

  let reserve ~now:now ~free:free ~q:needed ~running:running ~decision:decision =
    let rec fits f = function
      | [] -> failwith "impossible to backfill this job. check MaxProcs."
      | (t,i)::tis ->
          let f' = f+ (fj i).q
          in if f' >= needed then
            let resaWait = t-now;
            in ( assert ( resaWait > 0 ); ( resaWait  , f'-needed ))
            else
              fits (f') tis
    and projected =
      let sort = (List.sort (fun (t,_) (t',_) -> compare t t'))
      and project = (List.map (fun (t,i) -> (t+ (fj i).p_est,i)))
      in (running @ (List.map (fun i -> (now,i)) decision))
      |> project |> sort
    in fits free projected

  (*list jobs eligible for backfilling*)
  let eligible ~freeNow:r ~freeResa:r' ~resaWait:t ~idlist:idl =
    assert (t>0);
    assert (r>=0);
    assert (r'>=0);
    let p i =
      let j = fj i
      in j.q <= (min r' r) || (j.q <= r && j.p_est <= t)
    in List.filter p idl

  let schedule now s =
    match get_easy s.free (Primary.reorder s now s.waiting) with
      | Simple decision                     -> decision
      | Backfill (decision, _, _, [])       -> decision
      | Backfill (decision, free, id, rest) ->
          assert (free >= 0);
          let resaWait, resaFree =
            reserve ~now:now ~free:free ~q:(fj id).q ~running:s.running
              ~decision:decision
          in let () = assert (resaWait>0)
          in let () = assert (resaFree>=0)
          in let bfable = eligible ~freeNow:free ~freeResa:resaFree ~resaWait:resaWait ~idlist:rest
          in let backfilled =
            Secondary.pick ~system:s ~now:now ~backfillable:bfable
              ~reservationWait:resaWait ~reservationID:id ~reservationFree:resaFree
              ~freeNow:resaFree
          in decision @  backfilled
end

(*examples:*)
(*module MakeEasyGreedy(CR:Criteria)(CB:Criteria)(P:SchedulerParam) =*)
  (*MakeEasyScheduler(MakeGreedyPrimary(P)(CR))(MakeGreedySecondary(CB)(P))(P)*)

(*module MakeEasyEpsRandGreedy (E:EpsGreedyParameter)(CR:Criteria)(CB:Criteria)(P:SchedulerParam) =*)
(*MakeEasyScheduler(MakeGreedyPrimary(P)(CR))(MakeEpsGreedySecondary(E)(CB)(P))(P)*)

(*module MakeEasyRandom (CR:Criteria)(P: SchedulerParam) =*)
(*MakeEasyScheduler(MakeGreedyPrimary(P)(CR))(RandomSecondary)(P)*)

(*module MakeEasyHRandom(C1:Criteria)(C2:Criteria)(CR:Criteria)(P: SchedulerParam) =*)
(*MakeEasyScheduler(MakeGreedyPrimary(P)(CR))(MakeRandomHeuristicSecondary(C1)(C2)(P))(P)*)


(*module MakeBernouilliPrimary*)
(*(BP:BernouilliReservatorParam)*)
(*(P:SchedulerParam)*)
(*(R1:Primary)*)
(*(R2:Primary)*)
(*: Primary*)
(*= struct*)
  (*let reorder now l =*)
    (*let r = Random.float 1.*)
    (*in if r> BP.p then R1.reorder now l else R2.reorder now l *)
(*end*)


(*module type BernouilliParameter = sig*)
  (*val p : float*)
(*end*)

(*module MakeBernouilliHeuristicSecondary*)
(*(W:BernouilliParameter)*)
(*(C1:Criteria)*)
(*(C2:Criteria)*)
(*(P:SchedulerParam)*)
(*:Secondary = struct*)
  (*module H1 = MakeGreedySecondary(C1)(P)*)
  (*module H2 = MakeGreedySecondary(C2)(P)*)

  (*let selector now bfable restime resjob resres =*)
    (*let r = Random.float 1.*)
    (*in let sel = if r<W.p then*)
      (*H1.selector*)
    (*else*)
      (*H2.selector*)
    (*in sel now bfable restime resjob resres*)
(*end*)


(*module MakeEasyBernouilli(C1:Criteria)(C2:Criteria)(B:BernouilliReservatorParam)(CB:Criteria)(P: SchedulerParam) =*)
(*MakeEasyScheduler(MakeBernouilliPrimary(B)(P)(MakeGreedyPrimary(P)(C1))(MakeGreedyPrimary(P)(C2)))(MakeGreedySecondary(CB)(P))(P)*)


(*module type BernouilliReservatorParam = sig*)
  (*val p : float*)
(*end*)


(*module MakeRandomizedSecondary(C:Criteria)(P:SchedulerParam)*)
(*:Secondary*)
(*=struct*)
  (*(* pick a random id from this list -- the non-emply list*)
   (*should be in format [(proba,id);..] and the probabilities*)
   (*should add to 1. *)*)
  (*let pick_random_weighted (l: (float*int) list) : int =*)
    (*let r = Random.float (float_of_int 1)*)
    (*in let rec nextrandom s i' = function*)
      (*|(p,i)::is when s +. p >= r -> i*)
      (*|(p,i)::is -> nextrandom (s +. p) i is*)
      (*|[]-> i'*)
    (*in nextrandom 0. (snd (List.hd l)) l*)

  (*let selector (now:int) (bfable:int list) (restime:int) resjob resres =*)
    (*let weights : float list = List.map (C.criteria P.jobs now) bfable*)
    (*in let minweight = BatList.min weights*)
    (*in let scaledweights = List.map (fun x-> x-.minweight) weights*)
    (*in let sum : float = List.fold_left (fun acc x -> acc +. x) 0. scaledweights*)
    (*in let nd = List.map2 (fun x y -> (x /. sum, y)) scaledweights bfable*)
    (*in pick_random_weighted nd*)
(*end*)

(*module MakeEasyRandomizedGreedy (CR:Criteria)(CB:Criteria)(P:SchedulerParam) =*)
(*MakeEasyScheduler(MakeGreedyPrimary(P)(CR))(MakeRandomizedSecondary(CB)(P))(P)*)

(*module MakeEpsGreedySecondary(E:EpsGreedyParameter)(C:Criteria)(P:SchedulerParam)*)
(*:Secondary*)
(*= struct*)
  (*let selector (now:int) (bfable:int list) (restime:int) resjob resres =*)
    (*let id = List.hd bfable*)
    (*in let rec argmax v ip = function*)
    (*|i::is when v <= (C.criteria P.jobs now i) -> argmax (C.criteria P.jobs now i) i is*)
    (*|i::is -> argmax v ip is*)
    (*|[] -> ip*)
    (*in let r = Random.float (float_of_int 1)*)
    (*in if r<E.epsilon*)
    (*then*)
      (*List.nth bfable (Random.int (List.length bfable))*)
    (*else*)
      (*argmax (C.criteria P.jobs now id) id bfable*)
(*end*)

(*module type EpsGreedyParameter = sig*)
  (*val epsilon : float*)
(*end*)

(*module RandomSecondary : Secondary*)
(*= struct*)
  (*let selector _ bfable _ _ _ =*)
    (*let i =  Random.int (List.length bfable)*)
    (*in List.nth bfable i*)
(*end*)

(*module MakeRandomHeuristicSecondary*)
(*(C1:Criteria)*)
(*(C2:Criteria)*)
(*(P:SchedulerParam)*)
(*: Secondary*)
(*=struct*)
  (*module H1 = MakeGreedySecondary(C1)(P)*)
  (*module H2 = MakeGreedySecondary(C2)(P)*)

  (*let selector now bfable restime resjob resres =*)
    (*let h = Random.bool ()*)
    (*in let sel = if h then*)
      (*H1.selector*)
    (*else*)
      (*H2.selector*)
    (*in sel now bfable restime resjob resres*)
(*end*)
