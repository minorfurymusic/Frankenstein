/// Biblioteca de exercícios embarcada (offline): nome em português e grupo
/// muscular, para montar planos sem rede. Lista própria do RLT — nomes de
/// exercício são vocabulário comum de academia.
enum MuscleGroup {
  chest('Peito'),
  back('Costas'),
  shoulders('Ombros'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  legs('Pernas'),
  glutes('Glúteos'),
  core('Abdômen'),
  fullBody('Corpo inteiro');

  final String label;
  const MuscleGroup(this.label);
}

class CatalogExercise {
  final String id;
  final String name;
  final MuscleGroup group;
  const CatalogExercise(this.id, this.name, this.group);
}

const List<CatalogExercise> exerciseCatalog = [
  CatalogExercise('supino-reto', 'Supino reto', MuscleGroup.chest),
  CatalogExercise('supino-inclinado', 'Supino inclinado', MuscleGroup.chest),
  CatalogExercise('crucifixo', 'Crucifixo', MuscleGroup.chest),
  CatalogExercise('crossover', 'Crossover', MuscleGroup.chest),
  CatalogExercise('flexao', 'Flexão de braço', MuscleGroup.chest),
  CatalogExercise('puxada-frente', 'Puxada na frente', MuscleGroup.back),
  CatalogExercise('remada-curvada', 'Remada curvada', MuscleGroup.back),
  CatalogExercise('remada-baixa', 'Remada baixa', MuscleGroup.back),
  CatalogExercise('barra-fixa', 'Barra fixa', MuscleGroup.back),
  CatalogExercise('levantamento-terra', 'Levantamento terra', MuscleGroup.back),
  CatalogExercise('desenvolvimento', 'Desenvolvimento', MuscleGroup.shoulders),
  CatalogExercise('elevacao-lateral', 'Elevação lateral', MuscleGroup.shoulders),
  CatalogExercise('elevacao-frontal', 'Elevação frontal', MuscleGroup.shoulders),
  CatalogExercise('crucifixo-inverso', 'Crucifixo inverso', MuscleGroup.shoulders),
  CatalogExercise('rosca-direta', 'Rosca direta', MuscleGroup.biceps),
  CatalogExercise('rosca-alternada', 'Rosca alternada', MuscleGroup.biceps),
  CatalogExercise('rosca-martelo', 'Rosca martelo', MuscleGroup.biceps),
  CatalogExercise('triceps-pulley', 'Tríceps na polia', MuscleGroup.triceps),
  CatalogExercise('triceps-testa', 'Tríceps testa', MuscleGroup.triceps),
  CatalogExercise('mergulho', 'Mergulho (paralelas)', MuscleGroup.triceps),
  CatalogExercise('agachamento', 'Agachamento livre', MuscleGroup.legs),
  CatalogExercise('leg-press', 'Leg press', MuscleGroup.legs),
  CatalogExercise('cadeira-extensora', 'Cadeira extensora', MuscleGroup.legs),
  CatalogExercise('mesa-flexora', 'Mesa flexora', MuscleGroup.legs),
  CatalogExercise('afundo', 'Afundo', MuscleGroup.legs),
  CatalogExercise('panturrilha-em-pe', 'Panturrilha em pé', MuscleGroup.legs),
  CatalogExercise('stiff', 'Stiff', MuscleGroup.legs),
  CatalogExercise('elevacao-pelvica', 'Elevação pélvica', MuscleGroup.glutes),
  CatalogExercise('abducao', 'Cadeira abdutora', MuscleGroup.glutes),
  CatalogExercise('gluteo-polia', 'Glúteo na polia', MuscleGroup.glutes),
  CatalogExercise('prancha', 'Prancha', MuscleGroup.core),
  CatalogExercise('abdominal-supra', 'Abdominal supra', MuscleGroup.core),
  CatalogExercise('abdominal-infra', 'Abdominal infra', MuscleGroup.core),
  CatalogExercise('burpee', 'Burpee', MuscleGroup.fullBody),
  CatalogExercise('kettlebell-swing', 'Kettlebell swing', MuscleGroup.fullBody),
];

CatalogExercise? findCatalogExercise(String id) {
  for (final e in exerciseCatalog) {
    if (e.id == id) return e;
  }
  return null;
}
