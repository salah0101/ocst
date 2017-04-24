open Cmdliner
open Io
open Simulate

let copts_sect = "COMMON OPTIONS"
let help_secs = [
 `S copts_sect;
 `P "These options are common to all commands.";
 `S "MORE HELP";
 `P "Use `$(mname) $(i,COMMAND) --help' for help on a single command.";`Noblank;]

let help man_format cmds topic = match topic with
| None -> `Help (`Pager, None) (* help about the program. *)
| Some topic ->
    let topics = "topics" :: "patterns" :: "environment" :: cmds in
    let conv, _ = Cmdliner.Arg.enum (List.rev_map (fun s -> (s, s)) topics) in
    match conv topic with
    | `Error e -> `Error (false, e)
    | `Ok t when t = "topics" -> List.iter print_endline topics; `Ok ()
    | `Ok t when List.mem t cmds -> `Help (man_format, Some t)
    | `Ok t ->
        let page = (topic, 7, "", "", ""), [`S topic; `P "Say something";] in
        `Ok (Cmdliner.Manpage.print man_format Format.std_formatter page)

let copts_t =
  let docs = copts_sect in
  let debug =
    let doc = "Give debug output." in
    Arg.(value & flag & info ["debug"] ~docs ~doc)
  in let seed =
    let doc = "Random seed value." in
    Arg.(value & opt int 0 & info ["seed"] ~docv:"SEED" ~docs ~doc)
  in let maxprocs =
    let doc = "Enforce maxprocs value." in
    Arg.(value & opt int 0 & info ["maxprocs"] ~docv:"MAXPROCS" ~docs ~doc)
  in
  let swf_out =
    let doc = "Specify output swf file." in
    Arg.(value & opt (some string) None & info ["output"] ~docv:"OUTPUT" ~docs ~doc)
  in
  let backfill_out =
    let doc = "Specify output backfilling data file." in
    Arg.(value & opt (some string) None & info ["boutput"] ~docv:"BOUTPUT" ~docs ~doc)
  in
  let swf_in =
    let doc = "Input swf file." in
    Arg.(required & pos 0 (some file) None & info [] ~docv:"SWFINPUT" ~doc)
  in Term.(const copts $ swf_in $ swf_out $ backfill_out $ maxprocs $ debug $ seed)

let help_cmd =
  let topic =
    let doc = "The topic to get help on. `topics' lists the topics." in
    Arg.(value & pos 0 (some string) None & info [] ~docv:"TOPIC" ~doc)
  in
  let doc = "display help about ocs and ocs commands" in
  let man =
    [`S "DESCRIPTION";
     `P "Prints help about ocs commands and other subjects..."] @ help_secs
  in
  Term.(ret
          (const help $ Term.man_format $ Term.choice_names $topic)),
  Term.info "help" ~doc ~man

let mixed_cmd =
  let docs = copts_sect
  in let backfill =
    let doc = "Backfilling policy." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["backfill"] ~docv:"BACKFILL" ~doc)
  in let objective =
    let doc = "Objective for thresholding." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["th_objective"] ~docv:"TOBJECTIVE" ~doc)
  in let threshold =
    let doc = "Threshold value." in
    Arg.(value & opt float 10000. & info ["threshold"] ~docv:"THRESHOLD" ~doc)
  in let alpha =
    let doc = "Mixing parameter." in
    Arg.(value & opt (list ~sep:',' float) Metrics.zeroMixed & info ["alpha"] ~docv:"ALPHA" ~doc)
  in let mixingtype =
    let doc = "Mixing type." in
    Arg.(value & opt (enum Simulate.mixingList) (BatList.assoc "prob" Simulate.mixingList) & info ["mixtype"] ~docv:"MIXTYPE" ~doc)
  in
  let doc = "Simulate a EASY-backfilling scheduler with a mixed primary heuristic and a fixed BF heuristic, using thresholding on a main
  objective. The mixing is done using (1-alpha)*c1 + alpha*c2 where c1 and c2 are the two initial criterias" in
  let man =
    [`S "DESCRIPTION";
     `P doc] @ help_secs
  in
  Term.(const Simulate.mixed$ copts_t $ alpha $ backfill $ objective $ threshold $ mixingtype),
  Term.info "mixed" ~doc ~sdocs:docs ~man


let threshold_cmd =
  let docs = copts_sect
  in let reservation =
    let doc = "Primary policy." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["primary"] ~docv:"PRIMARY" ~doc)
  in let backfill =
    let doc = "Backfilling policy." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["backfill"] ~docv:"BACKFILL" ~doc)
  in let objective =
    let doc = "Objective for thresholding." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["th_objective"] ~docv:"TOBJECTIVE" ~doc)
  in let threshold =
    let doc = "Threshold value." in
    Arg.(value & opt float 10000. & info ["threshold"] ~docv:"THRESHOLD" ~doc)
  in
  let doc = "Simulate a EASY-backfilling scheduler with a fixed BF heuristic using thresholding on a main
  objective." in
  let man =
    [`S "DESCRIPTION";
     `P doc] @ help_secs
  in
  Term.(const Simulate.threshold $ copts_t $ reservation $ backfill $ objective $ threshold),
  Term.info "threshold" ~doc ~sdocs:docs ~man

let oneshot_cmd =
  let docs = copts_sect
  in let reservation =
    let doc = "Reservation type." in
    Arg.(required & pos 1 (some (enum Metrics.criteriaList)) None & info [] ~docv:"RESERVATION" ~doc)
  in let backfill =
    let doc = "Backfilling type." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["backfill"] ~docv:"BACKFILL" ~doc)
  in
  let doc = "Simulates the run of a classic EASY backfilling scheduler using a given reservation and backfill order." in
  let man =
    [`S "DESCRIPTION";
     `P doc] @ help_secs
  in
  Term.(const Simulate.oneshot $ copts_t $ reservation $ backfill ),
  Term.info "oneshot" ~doc ~sdocs:docs ~man

let bandit_random_cmd =
  let docs = copts_sect
  in let backfill =
    let doc = "Backfilling type." in
    Arg.(value & opt (enum Metrics.criteriaList) (module Metrics.CriteriaWait : Metrics.CriteriaSig) & info ["backfill"] ~docv:"BACKFILL" ~doc)
  in let policies=
    let doc = "Policies." in
    Arg.(value & opt (list ~sep:',' (enum Metrics.criteriaList)) Bandit.default_policies & info ["policies"] ~docv:"POLICIES" ~doc)
  in let period =
    let doc = "Period value." in
    Arg.(value & opt int 86400 & info ["period"] ~docv:"PERIOD" ~doc)
  in let threshold =
    let doc = "Threshold value." in
    Arg.(value & opt float 0. & info ["threshold"] ~docv:"THRESHOLD" ~doc)
  in
  let doc = "Simulates the run of a random Bandit EASY backfilling scheduler." in
  let man =
    [`S "DESCRIPTION";
     `P doc] @ help_secs
  in
  Term.(const Simulate.randomBandit $ copts_t $ period  $ backfill $ threshold $ policies),
  Term.info "bandit-random" ~doc ~sdocs:docs ~man

(*Arg.(value & opt (list ~sep:',' (pair ~sep:'-' (enum Metrics.criteriaList) (enum Metrics.criteriaList))) default_policies & info ["policies"] ~docv:"POLICIES" ~doc)*)

let bandit_cmd =
  let docs = copts_sect
  in let clairvoyant =
    let doc = "Use full feedback." in
    Arg.(value & flag & info ["clairvoyant"] ~docs ~doc)
  in let clvOut =
    let doc = "Clairvoyant output file." in
    Arg.(value & opt (some string) None & info ["clvo"] ~docv:"LOGCLV" ~doc)
  in let noisy =
    let doc = "Make the full feedback noisy." in
    Arg.(value & flag & info ["noisy"] ~docs ~doc)
  in let backfill =
    let doc = "Backfilling type." in
    Arg.(value & opt (enum Metrics.criteriaList) (BatList.assoc "wait" Metrics.criteriaList) & info ["backfill"] ~docv:"BACKFILL" ~doc)
  in let explo =
    let doc = "Bandit hyperparameter." in
    Arg.(value & opt float 0.7 & info ["hyperparameter"] ~docv:"HYPERPARAM" ~doc)
  in let policies=
    let doc = "Policies." in
    Arg.(value & opt (list ~sep:',' (enum Metrics.criteriaList)) Bandit.default_policies & info ["policies"] ~docv:"POLICIES" ~doc)
  in let rewardType =
    let doc = "Use opposite Reward." in
    Arg.(value & opt (enum Bandit.rewardTypeEncoding) Bandit.Basic & info ["rewardtype"] ~docs ~doc)
  in let period =
    let doc = "Period value." in
    Arg.(value & opt int 86400 & info ["period"] ~docv:"PERIOD" ~doc)
  in let threshold =
    let doc = "Threshold value." in
    Arg.(value & opt float 0. & info ["threshold"] ~docv:"THRESHOLD" ~doc)
  in let reset_out =
    let doc = "Specify reset output file." in
    Arg.(value & opt (some string) None & info ["reset"] ~docv:"RESET" ~doc)
  in let select_out =
    let doc = "Specify select output file." in
    Arg.(value & opt (some string) None & info ["select"] ~docv:"SELECT" ~doc)
  in
  let doc = "Simulates the run of a Bandit EASY backfilling scheduler." in
  let man =
    [`S "DESCRIPTION";
     `P doc] @ help_secs
  in
  Term.(const Simulate.bandit $ copts_t $ explo $ rewardType $ period  $ backfill $ threshold $ policies $ reset_out $ clairvoyant $ noisy $ select_out $ clvOut),
  Term.info "bandit-onpolicy" ~doc ~sdocs:docs ~man

let cmds = [mixed_cmd;bandit_random_cmd;bandit_cmd; oneshot_cmd; threshold_cmd; help_cmd]

let default_cmd =
  let doc = "a backfilling simulator" in
  let man = help_secs in
  Term.(ret (const  (`Help (`Pager, None)) )),
  Term.info "ocs" ~version:"0.1" ~sdocs:copts_sect ~doc ~man

let () = match Term.eval_choice default_cmd cmds with
  | `Error _ -> exit 1 | _ -> exit 0
