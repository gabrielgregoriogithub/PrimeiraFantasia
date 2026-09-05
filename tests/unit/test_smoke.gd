extends GutTest

## Fase 0: valida só que o pipeline headless do GUT está funcionando antes de
## portar qualquer regra de gameplay.

func test_gut_pipeline_works() -> void:
	assert_eq(1 + 1, 2, "sanity check")

