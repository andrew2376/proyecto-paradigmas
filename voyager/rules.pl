detected(symmetry).
detected(metallic_signature).
detected(non_random_geometry).

natural_explanation :-
    detected(volcanic_activity).

artificial_structure :-
    detected(symmetry),
    detected(metallic_signature),
    detected(non_random_geometry),
    \+ natural_explanation.

classify(non_natural_structure) :-
    artificial_structure.