from app.services.links import CODE_ALPHABET, generate_code


def test_generated_code_has_requested_shape():
    code = generate_code(12)

    assert len(code) == 12
    assert set(code) <= set(CODE_ALPHABET)


def test_generated_codes_are_not_constant():
    assert len({generate_code(7) for _ in range(20)}) == 20
