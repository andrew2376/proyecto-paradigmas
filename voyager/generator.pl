:- use_module(library(http/json)).
:- consult('rules.pl').

generate_report :-
    classify(Classification),

    Report = json([
        mission_id='VOYAGER_IX',
        classification=Classification,
        confidence=0.97,
        timestamp_utc='2041-10-17T14:22:31Z',
        rule_chain=json([
            step1='symmetry_detected',
            step2='metallic_signature_detected',
            step3='natural_origin_rejected'
        ])
    ]),

    open('voyager_report.json', write, Stream),
    json_write_dict(Stream, Report),
    close(Stream),

    write('VOYAGER REPORT GENERATED'), nl.