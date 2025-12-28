defmodule Philomena.Images.TagValidator do
  alias Philomena.Config
  import Ecto.Changeset

  def validate_tags(changeset) do
    tags = changeset |> get_field(:tags)

    changeset
    |> validate_tag_input(tags)
    |> set_rating_changed()
  end

  defp set_rating_changed(changeset) do
    added_tags = changeset |> get_field(:added_tags) |> extract_names()
    removed_tags = changeset |> get_field(:removed_tags) |> extract_names()
    ratings = all_ratings()

    added_ratings = MapSet.intersection(ratings, added_tags) |> MapSet.size()
    removed_ratings = MapSet.intersection(ratings, removed_tags) |> MapSet.size()

    put_change(changeset, :ratings_changed, added_ratings + removed_ratings > 0)
  end

  defp validate_tag_input(changeset, tags) do
    tag_set = extract_names(tags)
    rating_set = ratings(tag_set)

    changeset
    |> validate_number_of_tags(tag_set, 4)
    |> validate_bad_words(tag_set)
    |> validate_has_rating(rating_set)
    |> validate_sexual_exclusion(rating_set)
  end

  defp ratings(tag_set) do
    sexual = MapSet.intersection(tag_set, sexual_ratings())

    %{
      sexual: sexual,
    }
  end

  defp validate_number_of_tags(changeset, tag_set, num) do
    if MapSet.size(tag_set) < num do
      add_error(changeset, :tag_input, "must contain at least #{num} tags")
    else
      changeset
    end
  end

  def validate_bad_words(changeset, tag_set) do
    bad_words = MapSet.new(Config.get(:tag)["blacklist"])
    intersection = MapSet.intersection(tag_set, bad_words)

    if MapSet.size(intersection) > 0 do
      Enum.reduce(
        intersection,
        changeset,
        &add_error(&2, :tag_input, "contains forbidden tag `#{&1}'")
      )
    else
      changeset
    end
  end

  defp validate_has_rating(changeset, %{sexual: x}) do
    if MapSet.size(x) > 0 do
      changeset
    else
      add_error(changeset, :tag_input, "must contain at least one rating tag")
    end
  end

  defp extract_names(tags) do
    tags
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp all_ratings do
    sexual_ratings()
  end

  defp sexual_ratings, do: MapSet.new(["questionable", "explicit"])
end
