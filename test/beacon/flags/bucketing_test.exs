defmodule Beacon.Flags.BucketingTest do
  use ExUnit.Case, async: true

  alias Beacon.Flags.Bucketing

  describe "in_rollout?/3" do
    test "0% is never in rollout" do
      for subject <- ["user-1", "user-2", "user-3", "user-4"] do
        refute Bucketing.in_rollout?("new-dashboard", subject, 0)
      end
    end

    test "100% is always in rollout" do
      for subject <- ["user-1", "user-2", "user-3", "user-4"] do
        assert Bucketing.in_rollout?("new-dashboard", subject, 100)
      end
    end

    test "the same flag and subject always get the same answer" do
      results = for _ <- 1..5, do: Bucketing.in_rollout?("new-dashboard", "user-42", 50)
      assert Enum.uniq(results) == [hd(results)]
    end

    test "a 50% rollout lands roughly half of a large subject pool inside it" do
      subjects = for n <- 1..2000, do: "user-#{n}"
      in_count = Enum.count(subjects, &Bucketing.in_rollout?("new-dashboard", &1, 50))

      # Not exactly 1000 — it's a hash, not a coin flip assigned by us —
      # but a bucketing function that's secretly always-true, always-
      # false, or wildly skewed would fall outside this band.
      assert in_count in 800..1200
    end
  end
end
